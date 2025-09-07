class AddProjectedDatesToJiraIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :jira_issues, :refinement_projected_date, :date
    add_column :jira_issues, :deploy_projected_date, :date
  end
end
