class AddParentKeyToJiraIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :jira_issues, :parent_key, :string
  end
end
