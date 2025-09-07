# Configuration for mapping local database fields to Jira custom field IDs
# This extends the existing JIRA_CF_MAP to include the new fields
# that need to be updated back to Jira

if defined?(JIRA_CF_MAP)
  # Extend existing map with new fields for updating Jira
  JIRA_UPDATE_CF_MAP = JIRA_CF_MAP.merge({
    # Timestamp fields - map to your Jira custom field IDs
    # These are example IDs - replace with your actual custom field IDs
    'entered_requirements_at' => 'customfield_10291',
    'entered_discovery_at' => 'customfield_10292',
    'entered_ideation_at' => 'customfield_10293',
    'entered_validation_at' => 'customfield_10294',
    'entered_refinement_at' => 'customfield_10295',
    'entered_ready_for_dev_at' => 'customfield_10297',
    'entered_ready_for_review_at' => 'customfield_10298',
    'entered_ready_for_test_at' => 'customfield_10300',
    'entered_ready_for_deploy_at' => 'customfield_10302',
    'entered_developing_at' => 'customfield_10296',
    'entered_reviewing_at' => 'customfield_10299',
    'entered_testing_at' => 'customfield_10301',
    'entered_deployed_at' => 'customfield_10303',
    'entered_wrapup_at' => 'customfield_10304',
    'entered_done_at' => 'customfield_10305',
    'refinement_projected_date' => 'customfield_10357',
    'deploy_projected_date' => 'customfield_10358',
    
    # Reviewer and tester fields
    'reviewer' => 'customfield_10306',
    'tester' => 'customfield_10307'
  })
else
  # If JIRA_CF_MAP doesn't exist, create just the update map
  JIRA_UPDATE_CF_MAP = {
    # Timestamp fields - map to your Jira custom field IDs
    # These are example IDs - replace with your actual custom field IDs
    'entered_requirements_at' => 'customfield_10101',
    'entered_discovery_at' => 'customfield_10102',
    'entered_ideation_at' => 'customfield_10103',
    'entered_validation_at' => 'customfield_10104',
    'entered_refinement_at' => 'customfield_10105',
    'entered_ready_for_dev_at' => 'customfield_10106',
    'entered_ready_for_review_at' => 'customfield_10107',
    'entered_ready_for_test_at' => 'customfield_10108',
    'entered_ready_for_deploy_at' => 'customfield_10109',
    'entered_developing_at' => 'customfield_10110',
    'entered_reviewing_at' => 'customfield_10111',
    'entered_testing_at' => 'customfield_10112',
    'entered_deployed_at' => 'customfield_10113',
    'entered_wrapup_at' => 'customfield_10114',
    'entered_done_at' => 'customfield_10115',
    
    # Reviewer and tester fields
    'reviewer' => 'customfield_10116',
    'tester' => 'customfield_10117'
  }
end

# Instructions:
# 1. Create custom fields in your Jira instance for each timestamp and reviewer/tester
# 2. Get the custom field IDs from Jira (they look like customfield_XXXXX)
# 3. Replace the example IDs above with your actual custom field IDs
#
# Custom field types in Jira:
# - Timestamp fields should be "Date Time Picker" type
# - Reviewer/tester fields should be "Text Field (single line)" type
#
# To find custom field IDs:
# 1. Go to Jira Administration > Issues > Custom fields
# 2. Click on the field you want to find the ID for
# 3. Look at the URL - it will contain the custom field ID
# Example: .../secure/admin/EditCustomField!default.jspa?id=10100
# The ID is customfield_10100
