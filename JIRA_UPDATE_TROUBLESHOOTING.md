# Jira Update Troubleshooting Guide

## Issue Summary

The `jira:update_jira_issue[EPT-75]` command was not updating Jira because the custom field IDs in the configuration don't exist in the Jira instance.

## Root Cause

The error message from Jira API was:
```
"Field 'customfield_10116' cannot be set. It is not on the appropriate screen, or unknown."
```

This indicates that the custom field IDs (`customfield_10101` through `customfield_10117`) used in the configuration are example IDs that don't actually exist in the Jira instance.

## What Was Working

✅ **Local Data Population**: The local database fields (`entered_..._at`, `reviewer`, `tester`) are being populated correctly from changelog data.

✅ **Configuration Loading**: The `JIRA_UPDATE_CF_MAP` configuration is loading properly.

✅ **Field Mapping**: The field mapping logic is working correctly.

✅ **API Communication**: The Jira API communication is working (we received a proper error response).

## What Needs to Be Fixed

❌ **Custom Field IDs**: The custom field IDs in `config/initializers/jira_update_fields.rb` need to be replaced with actual custom field IDs from the Jira instance.

## Solution Steps

### 1. Create Custom Fields in Jira

You need to create the following custom fields in your Jira instance:

**Timestamp Fields (Date Time Picker type):**
- Entered Requirements At
- Entered Discovery At  
- Entered Ideation At
- Entered Validation At
- Entered Refinement At
- Entered Ready for Dev At
- Entered Ready for Review At
- Entered Ready for Test At
- Entered Ready for Deploy At
- Entered Developing At
- Entered Reviewing At
- Entered Testing At
- Entered Deployed At
- Entered Wrapup At
- Entered Done At

**Text Fields (Text Field single line type):**
- Reviewer
- Tester

### 2. Get Custom Field IDs

For each custom field you create:

1. Go to **Jira Administration** > **Issues** > **Custom fields**
2. Click on the field you want to find the ID for
3. Look at the URL - it will contain the custom field ID
   - Example: `.../secure/admin/EditCustomField!default.jspa?id=10100`
   - The ID is `customfield_10100`

### 3. Update Configuration

Edit `config/initializers/jira_update_fields.rb` and replace the example IDs with your actual custom field IDs:

```ruby
JIRA_UPDATE_CF_MAP = {
  # Timestamp fields - replace with your actual custom field IDs
  'entered_requirements_at' => 'customfield_XXXXX',  # Replace XXXXX
  'entered_discovery_at' => 'customfield_XXXXX',     # Replace XXXXX
  'entered_ideation_at' => 'customfield_XXXXX',      # Replace XXXXX
  # ... continue for all timestamp fields
  
  # Reviewer and tester fields
  'reviewer' => 'customfield_XXXXX',                 # Replace XXXXX
  'tester' => 'customfield_XXXXX'                    # Replace XXXXX
}
```

### 4. Test the Update

After updating the configuration:

```bash
bin/rails "jira:update_jira_issue[EPT-75]"
```

## Verification

To verify the update worked:

1. Check the Jira issue EPT-75 in the web interface
2. Look for the custom fields you created
3. Verify the values match what's in your local database

## Alternative: Use Environment Variables

Instead of hardcoding the custom field IDs in the configuration file, you can use environment variables:

```bash
# Set environment variables
export JIRA_CF_ENTERED_REQUIREMENTS_AT="customfield_10101"
export JIRA_CF_ENTERED_DISCOVERY_AT="customfield_10102"
# ... continue for all fields
```

Then the configuration will automatically pick up these environment variables.

## Debugging

If you need to debug the update process again, you can temporarily add debug output to the `JiraUpdater` and `JiraClient` classes as shown in the git history.

## Next Steps

1. Create the custom fields in Jira
2. Get the actual custom field IDs
3. Update the configuration
4. Test the update functionality
5. Remove any debug code if added

The core functionality is working correctly - it's just a matter of configuring the correct custom field IDs.
