class CreateJiraChangelogs < ActiveRecord::Migration[8.0]
  def change
    create_table :jira_changelogs do |t|
      t.references :jira_issue, null: false, foreign_key: true
      t.string :history_id
      t.string :author_account_id
      t.string :author_display_name
      t.datetime :created_at_jira
      t.jsonb :raw

      t.timestamps
    end
  end
end
