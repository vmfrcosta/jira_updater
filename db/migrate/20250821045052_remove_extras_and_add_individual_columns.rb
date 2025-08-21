class RemoveExtrasAndAddIndividualColumns < ActiveRecord::Migration[8.0]
  def change
    # Remove the extras column and its index
    remove_index :jira_issues, :extras, if_exists: true
    remove_column :jira_issues, :extras, if_exists: true
    
    # Add individual columns for data previously stored in extras
    add_column :jira_issues, :points, :integer
    add_column :jira_issues, :transitions_count, :integer
    add_column :jira_issues, :entered_requirements_at, :datetime
    add_column :jira_issues, :entered_discovery_at, :datetime
    add_column :jira_issues, :entered_ideation_at, :datetime
    add_column :jira_issues, :entered_validation_at, :datetime
    add_column :jira_issues, :entered_refinement_at, :datetime
    add_column :jira_issues, :entered_ready_for_dev_at, :datetime
    add_column :jira_issues, :entered_ready_for_review_at, :datetime
    add_column :jira_issues, :entered_ready_for_test_at, :datetime
    add_column :jira_issues, :entered_ready_for_deploy_at, :datetime
    add_column :jira_issues, :entered_developing_at, :datetime
    add_column :jira_issues, :entered_reviewing_at, :datetime
    add_column :jira_issues, :entered_testing_at, :datetime
    add_column :jira_issues, :entered_deployed_at, :datetime
    add_column :jira_issues, :entered_wrapup_at, :datetime
    add_column :jira_issues, :entered_done_at, :datetime
  end
end
