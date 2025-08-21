class JiraUpdater
  def initialize
    @client = JiraClient.new
    @cf_map = (defined?(JIRA_UPDATE_CF_MAP) && JIRA_UPDATE_CF_MAP.present?) ? JIRA_UPDATE_CF_MAP : {}
  end

  # Update all issues with local data to Jira
  def update_all_issues
    JiraIssue.find_each do |issue|
      Rails.logger.info("[JiraUpdater] Processing issue #{issue.key}")
      update_issue_in_jira(issue)
    end
  end

  # Update a specific issue with local data to Jira
  def update_issue_in_jira(jira_issue)
    return unless jira_issue.key.present?

    fields_to_update = build_update_fields(jira_issue)
    
    if fields_to_update.any?
      begin
        @client.update_issue(jira_issue.key, fields_to_update)
        Rails.logger.info("[JiraUpdater] Successfully updated #{jira_issue.key} with #{fields_to_update.keys.join(', ')}")
      rescue => e
        Rails.logger.error("[JiraUpdater] Failed to update #{jira_issue.key}: #{e.message}")
      end
    else
      Rails.logger.info("[JiraUpdater] No fields to update for #{jira_issue.key}")
    end
  end

  # Update only entered_..._at timestamps for all issues
  def update_all_timestamps
    JiraIssue.where.not(
      entered_requirements_at: nil
    ).or(
      JiraIssue.where.not(entered_discovery_at: nil)
    ).or(
      JiraIssue.where.not(entered_ideation_at: nil)
    ).or(
      JiraIssue.where.not(entered_validation_at: nil)
    ).or(
      JiraIssue.where.not(entered_refinement_at: nil)
    ).or(
      JiraIssue.where.not(entered_ready_for_dev_at: nil)
    ).or(
      JiraIssue.where.not(entered_ready_for_review_at: nil)
    ).or(
      JiraIssue.where.not(entered_ready_for_test_at: nil)
    ).or(
      JiraIssue.where.not(entered_ready_for_deploy_at: nil)
    ).or(
      JiraIssue.where.not(entered_developing_at: nil)
    ).or(
      JiraIssue.where.not(entered_reviewing_at: nil)
    ).or(
      JiraIssue.where.not(entered_testing_at: nil)
    ).or(
      JiraIssue.where.not(entered_deployed_at: nil)
    ).or(
      JiraIssue.where.not(entered_wrapup_at: nil)
    ).or(
      JiraIssue.where.not(entered_done_at: nil)
    ).find_each do |issue|
      Rails.logger.info("[JiraUpdater] Updating timestamps for #{issue.key}")
      update_timestamps_in_jira(issue)
    end
  end

  # Update only reviewer and tester for all issues
  def update_all_reviewer_tester
    JiraIssue.where.not(reviewer: nil).or(JiraIssue.where.not(tester: nil)).find_each do |issue|
      Rails.logger.info("[JiraUpdater] Updating reviewer/tester for #{issue.key}")
      update_reviewer_tester_in_jira(issue)
    end
  end

  private

  def build_update_fields(jira_issue)
    fields = {}
    
    # Add timestamp fields that have values
    timestamp_fields = build_timestamp_fields(jira_issue)
    fields.merge!(timestamp_fields)
    
    # Add reviewer and tester fields if they have values
    reviewer_tester_fields = build_reviewer_tester_fields(jira_issue)
    fields.merge!(reviewer_tester_fields)
    
    fields
  end

  def build_timestamp_fields(jira_issue)
    fields = {}
    
    # Map entered_..._at columns to their corresponding custom field IDs
    timestamp_mappings = {
      entered_requirements_at: get_custom_field_id('entered_requirements_at'),
      entered_discovery_at: get_custom_field_id('entered_discovery_at'),
      entered_ideation_at: get_custom_field_id('entered_ideation_at'),
      entered_validation_at: get_custom_field_id('entered_validation_at'),
      entered_refinement_at: get_custom_field_id('entered_refinement_at'),
      entered_ready_for_dev_at: get_custom_field_id('entered_ready_for_dev_at'),
      entered_ready_for_review_at: get_custom_field_id('entered_ready_for_review_at'),
      entered_ready_for_test_at: get_custom_field_id('entered_ready_for_test_at'),
      entered_ready_for_deploy_at: get_custom_field_id('entered_ready_for_deploy_at'),
      entered_developing_at: get_custom_field_id('entered_developing_at'),
      entered_reviewing_at: get_custom_field_id('entered_reviewing_at'),
      entered_testing_at: get_custom_field_id('entered_testing_at'),
      entered_deployed_at: get_custom_field_id('entered_deployed_at'),
      entered_wrapup_at: get_custom_field_id('entered_wrapup_at'),
      entered_done_at: get_custom_field_id('entered_done_at')
    }
    
    timestamp_mappings.each do |column, custom_field_id|
      next unless custom_field_id.present?
      
      value = jira_issue.send(column)
      if value.present?
        # Format datetime for Jira (ISO 8601 format)
        fields[custom_field_id] = value.iso8601
      end
    end
    
    fields
  end

  def build_reviewer_tester_fields(jira_issue)
    fields = {}
    
    # Add reviewer field if present
    reviewer_field_id = get_custom_field_id('reviewer')
    if reviewer_field_id.present? && jira_issue.reviewer.present?
      fields[reviewer_field_id] = jira_issue.reviewer
    end
    
    # Add tester field if present
    tester_field_id = get_custom_field_id('tester')
    if tester_field_id.present? && jira_issue.tester.present?
      fields[tester_field_id] = jira_issue.tester
    end
    
    fields
  end

  def update_timestamps_in_jira(jira_issue)
    fields = build_timestamp_fields(jira_issue)
    
    if fields.any?
      begin
        @client.update_issue(jira_issue.key, fields)
        Rails.logger.info("[JiraUpdater] Updated timestamps for #{jira_issue.key}")
      rescue => e
        Rails.logger.error("[JiraUpdater] Failed to update timestamps for #{jira_issue.key}: #{e.message}")
      end
    end
  end

  def update_reviewer_tester_in_jira(jira_issue)
    fields = build_reviewer_tester_fields(jira_issue)
    
    if fields.any?
      begin
        @client.update_issue(jira_issue.key, fields)
        Rails.logger.info("[JiraUpdater] Updated reviewer/tester for #{jira_issue.key}")
      rescue => e
        Rails.logger.error("[JiraUpdater] Failed to update reviewer/tester for #{jira_issue.key}: #{e.message}")
      end
    end
  end

  def get_custom_field_id(field_name)
    # This method should return the Jira custom field ID for the given field name
    # You'll need to map your local field names to Jira custom field IDs
    # This could come from environment variables, a configuration file, or the existing JIRA_CF_MAP
    
    # Check if the field is in the existing custom field map
    return @cf_map[field_name] if @cf_map[field_name].present?
    
    # Check environment variables for custom field mappings
    env_key = "JIRA_CF_#{field_name.upcase}"
    return ENV[env_key] if ENV[env_key].present?
    
    # Log warning if no mapping found
    Rails.logger.warn("[JiraUpdater] No custom field mapping found for #{field_name}")
    nil
  end

  # Class method to update all issues
  def self.update_all
    new.update_all_issues
  end

  # Class method to update timestamps only
  def self.update_timestamps
    new.update_all_timestamps
  end

  # Class method to update reviewer/tester only
  def self.update_reviewer_tester
    new.update_all_reviewer_tester
  end

  # Class method to update a specific issue
  def self.update_issue(jira_issue)
    new.update_issue_in_jira(jira_issue)
  end
end
