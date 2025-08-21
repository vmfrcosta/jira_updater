class AddReviewerAndTesterToJiraIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :jira_issues, :reviewer, :string
    add_column :jira_issues, :tester, :string
  end
end
