class ChangelogPopulator
    # Maps status names to the corresponding entered_..._at column names
    STATUS_TO_COLUMN_MAP = {
      'Requirements'      => :entered_requirements_at,
      'Discovery'         => :entered_discovery_at,
      'Ideation'          => :entered_ideation_at,
      'Validation'        => :entered_validation_at,
      'Refinement'        => :entered_refinement_at,
      'Ready for Dev'     => :entered_ready_for_dev_at,
      'Ready for Review'  => :entered_ready_for_review_at,
      'Ready for Test'    => :entered_ready_for_test_at,
      'Ready for Deploy'  => :entered_ready_for_deploy_at,
      'Developing'        => :entered_developing_at,
      'Reviewing'         => :entered_reviewing_at,
      'Testing'           => :entered_testing_at,
      'Deployed'          => :entered_deployed_at,
      'Wrap Up'           => :entered_wrapup_at,
      'Done'              => :entered_done_at
    }.freeze
  
    def initialize(jira_issue = nil)
      @jira_issue = jira_issue
    end
  
    # Popula timestamps + reviewer/tester para uma issue
    def populate_for_issue(jira_issue = nil)
      @jira_issue = jira_issue || @jira_issue
      raise ArgumentError, "jira_issue não definida" unless @jira_issue
  
      populate_entered_timestamps
      populate_reviewer_and_tester
      true
    end
  
    # Popula timestamps + reviewer/tester para todas as issues
    def populate_all_issues
      JiraIssue.includes(jira_changelogs: :jira_changelog_items).find_each do |issue|
        Rails.logger.info("[ChangelogPopulator] Processing issue #{issue.key}")
        self.class.new(issue).populate_for_issue
      end
      true
    end
  
    # Popula reviewer e tester para uma issue específica (instância)
    def populate_reviewer_and_tester(jira_issue = nil)
      @jira_issue = jira_issue || @jira_issue
      raise ArgumentError, "jira_issue não definida" unless @jira_issue
  
      populate_reviewer_and_tester_internal
      true
    end
  
    private
  
    def populate_entered_timestamps
        pp "populate_entered_timestamps"
      # Get all status transitions from changelog
      status_transitions = get_status_transitions
  
      # Oldest per target status
      oldest_entries = find_oldest_entries_by_status(status_transitions)
  
      # Persist
      update_issue_timestamps(oldest_entries)
    end
  
    def populate_reviewer_and_tester_internal
      # Get all status transitions with author information
      status_transitions_with_authors = get_status_transitions_with_authors
  
      reviewer_entry = find_first_status_transition(status_transitions_with_authors, 'Reviewing')
      tester_entry   = find_first_status_transition(status_transitions_with_authors, 'Testing')
  
      update_reviewer_and_tester(reviewer_entry, tester_entry)
    end
  
    def get_status_transitions
      transitions = []
  
      @jira_issue.jira_changelogs.includes(:jira_changelog_items).find_each do |changelog|
        changelog.jira_changelog_items.each do |item|
          next unless item.field == 'status'
  
          transitions << {
            from_status:  item.from_string,
            to_status:    item.to_string,
            timestamp:    changelog.created_at_jira,
            changelog_id: changelog.id
          }
        end
      end
  
      pp transitions

      transitions
    end
  
    def get_status_transitions_with_authors
      transitions = []
  
      @jira_issue.jira_changelogs.includes(:jira_changelog_items).find_each do |changelog|
        changelog.jira_changelog_items.each do |item|
          next unless item.field == 'status'
  
          transitions << {
            from_status:         item.from_string,
            to_status:           item.to_string,
            timestamp:           changelog.created_at_jira,
            author_display_name: changelog.author_display_name,
            author_account_id:   changelog.author_account_id,
            changelog_id:        changelog.id
          }
        end
      end
  
      transitions
    end
  
        def find_oldest_entries_by_status(transitions)
      oldest_entries = {}

      transitions.each do |transition|
        to_status  = transition[:to_status]
        # Find matching status in map (case-insensitive)
        column_name = find_matching_status_column(to_status)
        next unless column_name

        if !oldest_entries[column_name] || transition[:timestamp] < oldest_entries[column_name][:timestamp]
          oldest_entries[column_name] = {
            timestamp:    transition[:timestamp],
            from_status:  transition[:from_status],
            to_status:    to_status,
            changelog_id: transition[:changelog_id]
          }
        end
      end

      pp oldest_entries

      oldest_entries
    end

    def find_matching_status_column(status_name)
      STATUS_TO_COLUMN_MAP.each do |mapped_status, column|
        return column if status_name.downcase == mapped_status.downcase
      end
      nil
    end
  
    def find_first_status_transition(transitions, target_status)
      transitions
        .select { |t| t[:to_status].downcase == target_status.downcase }
        .min_by { |t| t[:timestamp] }
    end
  
    def update_issue_timestamps(oldest_entries)
      return if oldest_entries.blank?
  
      updates = {}
      ap oldest_entries
      oldest_entries.each { |column_name, entry| updates[column_name] = entry[:timestamp] }

  
      if updates.any?
        @jira_issue.update_columns(updates)
        Rails.logger.info("[ChangelogPopulator] Updated #{@jira_issue.key} timestamps: #{updates.keys.join(', ')}")
      end
    end
  
    def update_reviewer_and_tester(reviewer_entry, tester_entry)
      updates = {}
  
      if reviewer_entry
        updates[:reviewer] = reviewer_entry[:author_display_name]
        Rails.logger.info("[ChangelogPopulator] Set reviewer for #{@jira_issue.key}: #{reviewer_entry[:author_display_name]}")
      end
  
      if tester_entry
        updates[:tester] = tester_entry[:author_display_name]
        Rails.logger.info("[ChangelogPopulator] Set tester for #{@jira_issue.key}: #{tester_entry[:author_display_name]}")
      end
  
      @jira_issue.update_columns(updates) if updates.any?
    end
  
    # Helper opcional para inspeção rápida
    def get_population_summary
      return {} unless @jira_issue
  
      summary = {}
      STATUS_TO_COLUMN_MAP.each_value do |column|
        val = @jira_issue.send(column)
        summary[column] = val if val.present?
      end
      summary[:reviewer] = @jira_issue.reviewer if @jira_issue.reviewer.present?
      summary[:tester]   = @jira_issue.tester   if @jira_issue.tester.present?
      summary
    end
  
    # ===== Class methods =====
  
    # Popula uma única issue
    def self.populate_issue(jira_issue)
      new(jira_issue).populate_for_issue
    end
  
    # Popula todas as issues
    def self.populate_all
      new.populate_all_issues
    end
end
    