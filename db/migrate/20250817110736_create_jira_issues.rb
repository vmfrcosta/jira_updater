class CreateJiraIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :jira_issues do |t|
      t.string :jira_id
      t.string :key
      t.string :summary
      t.string :status
      t.string :issue_type
      t.string :priority
      t.string :project_key
      t.date :start_date
      t.date :end_date
      t.text :labels
      t.json :raw

      t.timestamps
    end
  end
end
