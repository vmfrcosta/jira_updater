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
end
  