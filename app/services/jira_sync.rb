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
      raw:         issue
    }.merge(individual_fields)

    record = JiraIssue.find_or_initialize_by(key: key)
    record.assign_attributes(attrs)
    record.save!

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
end
