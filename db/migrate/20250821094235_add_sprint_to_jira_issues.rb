class AddSprintToJiraIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :jira_issues, :sprint, :string
  end
end
