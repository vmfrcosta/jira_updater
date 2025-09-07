namespace :jira do
  desc "Sincroniza issues do Jira conforme JQL"
  task sync: :environment do
    puts "Sync iniciada..."
    JiraSync.new.run!
    puts "Sync concluída. Total de issues: #{JiraIssue.count}"
  end

  desc "Sincroniza changelog para issues existentes"
  task sync_changelog: :environment do
    puts "Sync de changelog iniciada..."
    JiraSync.new.sync_changelog_for_existing_issues!
    puts "Sync de changelog concluída."
  end

  desc "Popula colunas entered_..._at com dados do changelog"
  task populate_entered_timestamps: :environment do
    puts "Populando colunas entered_..._at..."
    ChangelogPopulator.populate_all
    puts "População concluída."
  end

  desc "Popula colunas entered_..._at para uma issue específica"
  task :populate_issue_timestamps, [:issue_key] => :environment do |t, args|
    issue_key = args[:issue_key]
    if issue_key.blank?
      puts "Erro: Forneça a chave da issue. Ex: rails jira:populate_issue_timestamps[ISSUE-123]"
      exit 1
    end

    issue = JiraIssue.find_by(key: issue_key)
    if issue.nil?
      puts "Erro: Issue #{issue_key} não encontrada."
      exit 1
    end

    puts "Populando timestamps para #{issue_key}..."
    ChangelogPopulator.populate_issue(issue)
    puts "População concluída."
  end

  desc "Popula colunas reviewer e tester com dados do changelog"
  task populate_reviewer_and_tester: :environment do
    puts "Populando colunas reviewer e tester..."
    JiraIssue.includes(:jira_changelogs => :jira_changelog_items).find_each do |issue|
      Rails.logger.info("[JiraRake] Processing reviewer/tester for #{issue.key}")
      ChangelogPopulator.new.populate_reviewer_and_tester(issue)
    end
    puts "População concluída."
  end

  desc "Popula reviewer e tester para uma issue específica"
  task :populate_issue_reviewer_tester, [:issue_key] => :environment do |t, args|
    issue_key = args[:issue_key]
    if issue_key.blank?
      puts "Erro: Forneça a chave da issue. Ex: rails jira:populate_issue_reviewer_tester[ISSUE-123]"
      exit 1
    end

    issue = JiraIssue.find_by(key: issue_key)
    if issue.nil?
      puts "Erro: Issue #{issue_key} não encontrada."
      exit 1
    end

    puts "Populando reviewer/tester para #{issue_key}..."
    ChangelogPopulator.new.populate_reviewer_and_tester(issue)
    puts "População concluída."
  end

  desc "Atualiza todas as issues no Jira com dados locais"
  task update_jira_all: :environment do
    puts "Atualizando todas as issues no Jira com dados locais..."
    JiraUpdater.update_all
    puts "Atualização concluída."
  end

  desc "Atualiza apenas timestamps (entered_..._at) no Jira"
  task update_jira_timestamps: :environment do
    puts "Atualizando timestamps no Jira..."
    JiraUpdater.update_timestamps
    puts "Atualização de timestamps concluída."
  end

  desc "Atualiza apenas reviewer e tester no Jira"
  task update_jira_reviewer_tester: :environment do
    puts "Atualizando reviewer e tester no Jira..."
    JiraUpdater.update_reviewer_tester
    puts "Atualização de reviewer/tester concluída."
  end

  desc "Atualiza uma issue específica no Jira com dados locais"
  task :update_jira_issue, [:issue_key] => :environment do |t, args|
    issue_key = args[:issue_key]
    if issue_key.blank?
      puts "Erro: Forneça a chave da issue. Ex: rails jira:update_jira_issue[ISSUE-123]"
      exit 1
    end

    issue = JiraIssue.find_by(key: issue_key)
    if issue.nil?
      puts "Erro: Issue #{issue_key} não encontrada."
      exit 1
    end

    puts "Atualizando #{issue_key} no Jira..."
    JiraUpdater.update_issue(issue)
    puts "Atualização concluída."
  end

  desc "Atualiza issues no Jira que foram atualizadas nos últimos N dias (padrão: 14 dias)"
  task :update_jira_recent, [:days] => :environment do |t, args|
    days = args[:days].present? ? args[:days].to_i : 14
    
    if days <= 0
      puts "Erro: O número de dias deve ser maior que 0."
      exit 1
    end

    puts "Atualizando issues no Jira que foram atualizadas nos últimos #{days} dias..."
    updated_count = JiraUpdater.update_recent_issues(days)
    puts "Atualização concluída. #{updated_count} issues atualizadas."
  end

  desc "Sincroniza informações de parent para issues existentes"
  task sync_parents: :environment do
    puts "Sincronizando informações de parent..."
    
    total_issues = JiraIssue.count
    updated_count = 0
    
    JiraIssue.find_each do |issue|
      begin
        # Fetch fresh data from Jira to get parent information
        response = JiraClient.new.search(
          jql: "key = #{issue.key}",
          fields: %w[parent]
        )
        
        if response["issues"]&.any?
          jira_data = response["issues"].first
          parent_key = extract_parent_key_from_response(jira_data)
          
          if issue.parent_key != parent_key
            issue.update!(parent_key: parent_key)
            updated_count += 1
            puts "Updated parent for #{issue.key}: #{parent_key || 'none'}"
          end
        end
      rescue => e
        puts "Error syncing parent for #{issue.key}: #{e.message}"
      end
    end
    
    puts "Parent sync concluída. #{updated_count} issues atualizadas."
  end

  desc "Sincroniza informações de assignee para issues existentes"
  task sync_assignees: :environment do
    puts "Sincronizando informações de assignee..."
    
    total_issues = JiraIssue.count
    updated_count = 0
    
    JiraIssue.find_each do |issue|
      begin
        # Fetch fresh data from Jira to get assignee information
        response = JiraClient.new.search(
          jql: "key = #{issue.key}",
          fields: %w[assignee]
        )
        
        if response["issues"]&.any?
          jira_data = response["issues"].first
          assignee = extract_assignee_from_response(jira_data)
          
          if issue.assignee != assignee
            issue.update!(assignee: assignee)
            updated_count += 1
            puts "Updated assignee for #{issue.key}: #{assignee || 'none'}"
          end
        end
      rescue => e
        puts "Error syncing assignee for #{issue.key}: #{e.message}"
      end
    end
    
    puts "Assignee sync concluída. #{updated_count} issues atualizadas."
  end

  desc "Sincroniza contagem de children para issues existentes"
  task sync_children_count: :environment do
    puts "Sincronizando contagem de children..."
    
    total_issues = JiraIssue.count
    updated_count = 0
    
    JiraIssue.find_each do |issue|
      begin
        children_count = JiraIssue.where(parent_key: issue.key).count
        
        if issue.children_count != children_count
          issue.update!(children_count: children_count)
          updated_count += 1
          puts "Updated children count for #{issue.key}: #{children_count}"
        end
      rescue => e
        puts "Error syncing children count for #{issue.key}: #{e.message}"
      end
    end
    
    puts "Children count sync concluída. #{updated_count} issues atualizadas."
  end

  desc "Testa métricas do dashboard ágil"
  task test_agile_metrics: :environment do
    puts "Testando métricas do dashboard ágil..."
    
    # Test with last 4 weeks
    start_date = 4.weeks.ago.beginning_of_week
    end_date = Time.current.end_of_week
    
    metrics_service = AgileMetricsService.new(start_date, end_date)
    
    puts "Período: #{start_date.strftime('%Y-%m-%d')} até #{end_date.strftime('%Y-%m-%d')}"
    puts ""
    
    # Overall metrics
    overall = metrics_service.overall_metrics
    puts "=== Métricas Gerais ==="
    puts "Cycle Time: #{overall[:cycle_time]} dias"
    puts "Lead Time: #{overall[:lead_time]} dias"
    puts "Throughput: #{overall[:throughput]} issues"
    puts "Total Issues: #{overall[:total_issues]}"
    puts "Total Effort: #{overall[:total_effort]} pontos"
    puts "Total Bugs: #{overall[:total_bugs_solved]}"
    puts ""
    
    # Weekly metrics
    weekly = metrics_service.weekly_metrics
    puts "=== Métricas Semanais ==="
    weekly.each do |week|
      puts "Semana: #{week[:week_label]}"
      puts "  Cycle Time: #{week[:metrics][:cycle_time]} dias"
      puts "  Lead Time: #{week[:metrics][:lead_time]} dias"
      puts "  Throughput: #{week[:metrics][:throughput]}"
      puts "  Total Issues: #{week[:metrics][:total_issues]}"
      puts "  Total Effort: #{week[:metrics][:total_effort]} pontos"
      puts "  Bugs: #{week[:metrics][:total_bugs_solved]}"
      puts ""
    end
    
    # Effort by assignee
    puts "=== Esforço por Assignee ==="
    overall[:effort_by_assignee].each do |assignee, effort|
      puts "#{assignee}: #{effort} pontos"
    end
    puts ""
    
    # Bugs by assignee
    puts "=== Bugs por Assignee ==="
    overall[:bugs_by_assignee].each do |assignee, bugs|
      puts "#{assignee}: #{bugs} bugs"
    end
  end

  private

  def extract_parent_key_from_response(jira_data)
    parent = jira_data.dig("fields", "parent")
    return nil unless parent
    
    case parent
    when String
      parent
    when Hash
      parent["key"]
    else
      nil
    end
  end

  def extract_assignee_from_response(jira_data)
    assignee = jira_data.dig("fields", "assignee")
    return nil unless assignee
    
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

    desc "Delete a Jira issue"
  task :delete_issue, [:issue_key] => :environment do |task, args|
    issue_key = args[:issue_key]

    if issue_key.blank?
      puts "Error: Please provide an issue key. Usage: rake jira:delete_issue[ISSUE-KEY]"
      exit 1
    end

    puts "Attempting to delete issue: #{issue_key}"

    begin
      client = JiraClient.new
      success = client.delete_issue(issue_key)

      if success
        puts "✅ Successfully deleted issue: #{issue_key}"
      else
        puts "❌ Failed to delete issue: #{issue_key}"
      end
    rescue => e
      puts "❌ Error deleting issue #{issue_key}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Sync sprint data for existing issues"
  task :sync_sprints => :environment do
    puts "🔄 Syncing sprint data for existing issues..."

    begin
      client = JiraClient.new
      total_issues = JiraIssue.count
      updated_count = 0

      # Process issues in batches to avoid memory issues
      JiraIssue.find_in_batches(batch_size: 50) do |batch|
        batch.each do |issue|
          begin
            # Fetch fresh data from Jira for this issue
            response = client.search(
              jql: "key = #{issue.key}",
              max_results: 1,
              fields: ['sprint', 'summary', 'status'] # Only fetch needed fields
            )

            if response["issues"]&.any?
              jira_data = response["issues"].first
              fields = jira_data["fields"] || {}
              
              # Extract sprint information
              sprint_field = fields["sprint"]
              new_sprint = nil
              
              if sprint_field
                case sprint_field
                when Array
                  sprint = sprint_field.last
                  new_sprint = sprint["name"] || sprint["displayName"] if sprint
                when Hash
                  new_sprint = sprint_field["name"] || sprint_field["displayName"]
                when String
                  new_sprint = sprint_field
                end
              end

              # Update if sprint has changed
              if issue.sprint != new_sprint
                issue.update!(sprint: new_sprint)
                updated_count += 1
                puts "✅ Updated #{issue.key}: sprint = #{new_sprint || 'None'}"
              end
            end
          rescue => e
            puts "❌ Error syncing sprint for #{issue.key}: #{e.message}"
          end
        end
      end

      puts "🎉 Sprint sync completed!"
      puts "📊 Total issues processed: #{total_issues}"
      puts "📝 Issues updated: #{updated_count}"
    rescue => e
      puts "❌ Error during sprint sync: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Check available fields for an issue"
  task :check_fields, [:issue_key] => :environment do |task, args|
    issue_key = args[:issue_key]

    if issue_key.blank?
      puts "Error: Please provide an issue key. Usage: rake jira:check_fields[ISSUE-KEY]"
      exit 1
    end

    puts "🔍 Checking available fields for issue: #{issue_key}"

    begin
      client = JiraClient.new
      
      # Fetch issue data with all fields
      response = client.search(
        jql: "key = #{issue_key}",
        max_results: 1
      )

      if response["issues"]&.any?
        jira_data = response["issues"].first
        fields = jira_data["fields"] || {}
        
        puts "📋 Issue: #{jira_data['key']}"
        puts "📝 Summary: #{fields['summary']}"
        puts "📊 Status: #{fields.dig('status', 'name')}"
        
        # Look for sprint-related fields
        puts "\n🔍 Searching for sprint-related fields..."
        fields.each do |field_name, field_value|
          if field_name.downcase.include?('sprint') || 
             (field_value.is_a?(String) && field_value.downcase.include?('sprint')) ||
             (field_value.is_a?(Array) && field_value.any? { |v| v.to_s.downcase.include?('sprint') })
            puts "🏃 Found field: #{field_name} = #{field_value.inspect}"
          end
        end
        
        # Also check for common sprint field names
        sprint_field_names = ['sprint', 'Sprint', 'SPRINT', 'sprints', 'Sprints', 'SPRINTS']
        sprint_field_names.each do |field_name|
          if fields[field_name]
            puts "✅ Found sprint field '#{field_name}': #{fields[field_name].inspect}"
          end
        end
      else
        puts "❌ Issue not found in Jira"
      end
    rescue => e
      puts "❌ Error checking fields: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Sync projected dates for existing issues"
  task :sync_projected_dates => :environment do
    puts "🔄 Syncing projected dates for existing issues..."

    begin
      client = JiraClient.new
      total_issues = JiraIssue.count
      updated_count = 0

      # Process issues in batches to avoid memory issues
      JiraIssue.find_in_batches(batch_size: 50) do |batch|
        batch.each do |issue|
          begin
            # Fetch fresh data from Jira for this issue
            response = client.search(
              jql: "key = #{issue.key}",
              max_results: 1,
              fields: ['customfield_10358', 'customfield_10357', 'summary', 'status'] # refinement and deploy projected dates
            )

            if response["issues"]&.any?
              jira_data = response["issues"].first
              fields = jira_data["fields"] || {}
              
              # Extract projected dates
              refinement_projected = extract_projected_date(fields, 'customfield_10357')
              deploy_projected = extract_projected_date(fields, 'customfield_10358')

              # Update if projected dates have changed
              changes = {}
              changes[:refinement_projected_date] = refinement_projected if issue.refinement_projected_date != refinement_projected
              changes[:deploy_projected_date] = deploy_projected if issue.deploy_projected_date != deploy_projected

              if changes.any?
                issue.update!(changes)
                updated_count += 1
                puts "✅ Updated #{issue.key}: #{changes.inspect}"
              end
            end
          rescue => e
            puts "❌ Error syncing projected dates for #{issue.key}: #{e.message}"
          end
        end
      end

      puts "🎉 Projected dates sync completed!"
      puts "📊 Total issues processed: #{total_issues}"
      puts "📝 Issues updated: #{updated_count}"
    rescue => e
      puts "❌ Error during projected dates sync: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  private

  def extract_projected_date(fields, cf_id)
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
end
  