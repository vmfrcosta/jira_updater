class JiraSync
  def initialize(jql: ENV.fetch("JIRA_JQL"))
    @jql         = jql
    @client      = JiraClient.new
    @start_field = ENV["JIRA_TARGET_START_FIELD"]
    @end_field   = ENV["JIRA_TARGET_END_FIELD"]
    @cf_map      = (defined?(JIRA_CF_MAP) && JIRA_CF_MAP.present?) ? JIRA_CF_MAP : {}
  end

  def run!
    start_at = 0
    loop do
      res    = @client.search(jql: @jql, start_at: start_at)
      issues = res["issues"] || []
      upsert_batch(issues)
      start_at += issues.size
      break if issues.empty? || start_at >= res["total"].to_i
    end
  end

  # Sync changelog for existing issues that don't have changelog data
  def sync_changelog_for_existing_issues!
    JiraIssue.where.missing(:jira_changelogs).find_each do |issue|
      sync_issue_changelog(issue)
      Rails.logger.info("[JiraSync] Synced changelog for #{issue.key}")
    end
  end

  private

  def sync_issue_changelog(jira_issue)
    start_at = 0
    loop do
      changelog_response = @client.get_changelog(jira_issue.key, start_at: start_at)
      histories = changelog_response["values"] || []
      
      histories.each do |history|
        # Skip if this changelog entry already exists
        next if jira_issue.jira_changelogs.exists?(history_id: history["id"])

        changelog = jira_issue.jira_changelogs.create!(
          history_id: history["id"],
          author_account_id: history.dig("author", "accountId"),
          author_display_name: history.dig("author", "displayName"),
          created_at_jira: history["created"],
          raw: history
        )

        # Process changelog items
        if history["items"]
          history["items"].each do |item|
            changelog.jira_changelog_items.create!(
              field: item["field"],
              fieldtype: item["fieldtype"],
              from_value: item["from"],
              from_string: item["fromString"],
              to_value: item["to"],
              to_string: item["toString"]
            )
          end
        end
      end

      start_at += histories.size
      break if histories.empty? || start_at >= changelog_response["total"].to_i
    end

    # Populate entered_..._at timestamps after syncing changelog
    ChangelogPopulator.populate_issue(jira_issue)
  rescue => e
    Rails.logger.error("[JiraSync] Error syncing changelog for #{jira_issue.key}: #{e.message}")
  end

  def upsert_batch(issues)
    issues.each { |issue| upsert_issue(issue) }
  end

  def upsert_issue(issue)
    fields = issue["fields"] || {}
    key    = issue["key"]

    # Extract individual field values
    individual_fields = extract_individual_fields(fields)

    attrs = {
      jira_id:     issue["id"],
      key:         key,
      summary:     fields.dig("summary"),
      status:      fields.dig("status", "name"),
      issue_type:  fields.dig("issuetype", "name"),
      priority:    fields.dig("priority", "name"),
      project_key: fields.dig("project", "key"),
      start_date:  extract_date(fields, @start_field),
      end_date:    extract_date(fields, @end_field),
      labels:      fields["labels"] || [],
      parent_key:  extract_parent_key(fields),
      assignee:    extract_assignee(fields),
      sprint:      extract_sprint(fields),
      refinement_projected_date: extract_projected_date(fields, 'refinement_projected_date'),
      deploy_projected_date: extract_due_date(fields),
      br_us: extract_br_us(fields),
      raw:         issue
    }.merge(individual_fields)

    record = JiraIssue.find_or_initialize_by(key: key)
    record.assign_attributes(attrs)
    record.save!

    # Calculate and update children count
    children_count = JiraIssue.where(parent_key: key).count
    record.update_column(:children_count, children_count) if record.children_count != children_count

    # Process changelog information
    process_changelog(record, issue)

    # Populate entered_..._at timestamps after processing changelog
    ChangelogPopulator.populate_issue(record)

    Rails.logger.info("[JiraSync] upsert #{key} individual_fields=#{individual_fields.compact.inspect}")
  end

  def extract_individual_fields(fields)
    result = {}
    
    @cf_map.each do |human_key, cf_id|
      raw_val = fields[cf_id]
      result[human_key] = normalize_value(raw_val)
    end

    result
  end

  def process_changelog(jira_issue, issue_data)
    changelog_data = issue_data["changelog"]
    return unless changelog_data && changelog_data["histories"]

    changelog_data["histories"].each do |history|
      # Skip if this changelog entry already exists
      next if jira_issue.jira_changelogs.exists?(history_id: history["id"])

      changelog = jira_issue.jira_changelogs.create!(
        history_id: history["id"],
        author_account_id: history.dig("author", "accountId"),
        author_display_name: history.dig("author", "displayName"),
        created_at_jira: history["created"],
        raw: history
      )

      # Process changelog items
      if history["items"]
        history["items"].each do |item|
          changelog.jira_changelog_items.create!(
            field: item["field"],
            fieldtype: item["fieldtype"],
            from_value: item["from"],
            from_string: item["fromString"],
            to_value: item["to"],
            to_string: item["toString"]
          )
        end
      end
    end
  end

  def extract_date(fields, custom_id)
    return nil if custom_id.blank?
    val = fields[custom_id]
    case val
    when String
      Date.parse(val) rescue nil
    when Hash
      Date.parse(val["start"] || val["end"] || val["value"].to_s) rescue nil
    else
      nil
    end
  end

  def normalize_value(value)
    case value
    when Hash
      # Datas de automation do Jira costumam chegar como string
      if value["start"] || value["end"] || value["value"]
        value["start"] || value["end"] || value["value"]
      else
        value
      end
    else
      value
    end
  end

  def extract_parent_key(fields)
    parent = fields["parent"]
    return nil unless parent
    
    # Parent can be either a simple key string or a full object
    case parent
    when String
      parent
    when Hash
      parent["key"]
    else
      nil
    end
  end

  def extract_assignee(fields)
    assignee = fields["assignee"]
    return nil unless assignee
    
    # Assignee can be either a simple string or a full object
    case assignee
    when String
      assignee
    when Hash
      # Prefer displayName, fallback to name, then accountId
      assignee["displayName"] || assignee["name"] || assignee["accountId"]
    else
      nil
    end
  end

  def extract_sprint(fields)
    sprint_field = fields["sprint"]
    return nil unless sprint_field
    
    # Sprint field can be an array of sprint objects
    case sprint_field
    when Array
      # Get the most recent sprint (usually the last one in the array)
      sprint = sprint_field.last
      return nil unless sprint
      
      # Extract sprint name from the sprint object
      case sprint
      when Hash
        sprint["name"] || sprint["displayName"]
      when String
        sprint
      else
        nil
      end
    when Hash
      # Single sprint object
      sprint_field["name"] || sprint_field["displayName"]
    when String
      # Direct sprint name
      sprint_field
    else
      nil
    end
  end

  def extract_projected_date(fields, field_name)
    # Get the custom field ID from the mapping
    cf_id = @cf_map[field_name]
    return nil unless cf_id
    
    # Extract the date value from the custom field
    date_value = fields[cf_id]
    return nil unless date_value
    
    case date_value
    when String
      Date.parse(date_value) rescue nil
    when Hash
      # Handle date picker fields that might have a 'value' key
      date_str = date_value["value"] || date_value["start"] || date_value["end"]
      Date.parse(date_str) rescue nil if date_str
    else
      nil
    end
  end

  def extract_due_date(fields)
    # Extract the due date from the standard Jira due date field
    due_date = fields["duedate"]
    return nil unless due_date
    
    case due_date
    when String
      Date.parse(due_date) rescue nil
    when Hash
      # Handle date picker fields that might have a 'value' key
      date_str = due_date["value"] || due_date["start"] || due_date["end"]
      Date.parse(date_str) rescue nil if date_str
    else
      nil
    end
  end

  def extract_br_us(fields)
    # Extract the BR / US field from custom field customfield_10310
    br_us_field = fields["customfield_10310"]
    return nil unless br_us_field
    
    case br_us_field
    when Array
      # Multiple choice select list - join values with comma
      br_us_field.map { |item| item["value"] || item }.join(" / ")
    when Hash
      # Single choice or object format
      br_us_field["value"] || br_us_field["name"] || br_us_field.to_s
    when String
      # Direct string value
      br_us_field
    else
      nil
    end
  end
end
