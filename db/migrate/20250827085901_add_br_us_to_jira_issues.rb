class AddBrUsToJiraIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :jira_issues, :br_us, :string
  end
end
