class CreateJiraChangelogItems < ActiveRecord::Migration[8.0]
  def change
    create_table :jira_changelog_items do |t|
      t.references :jira_changelog, null: false, foreign_key: true
      t.string :field
      t.string :fieldtype
      t.string :from_value
      t.string :from_string
      t.string :to_value
      t.string :to_string

      t.timestamps
    end
  end
end
