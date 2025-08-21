# db/migrate/XXXXXXXXXXXX_change_labels_to_array_on_jira_issues.rb
class ChangeLabelsToArrayOnJiraIssues < ActiveRecord::Migration[7.1]
  def up
    add_column :jira_issues, :labels_tmp, :string, array: true, default: [], null: false
    execute <<~SQL
      UPDATE jira_issues
      SET labels_tmp = CASE
        WHEN labels IS NULL THEN '{}'
        WHEN labels::text LIKE '[%' THEN ARRAY(SELECT json_array_elements_text(labels::json))
        ELSE ARRAY[labels::text]
      END
    SQL
    remove_column :jira_issues, :labels
    rename_column :jira_issues, :labels_tmp, :labels
  end

  def down
    add_column :jira_issues, :labels_old, :text
    remove_column :jira_issues, :labels
    rename_column :jira_issues, :labels_old, :labels
  end
end
