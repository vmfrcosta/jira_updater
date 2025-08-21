# Jira Update Documentation

This document explains how to update Jira issues with local data from the `entered_..._at`, `reviewer`, and `tester` columns.

## Overview

The system can push data back to Jira by updating custom fields with the calculated timestamps and identified users. This allows you to keep Jira synchronized with the analyzed changelog data.

## Prerequisites

### 1. Jira Custom Fields Setup

You need to create custom fields in your Jira instance for each piece of data you want to update:

#### Timestamp Fields (Date Time Picker type)
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
- Entered Wrap Up At
- Entered Done At

#### User Fields (Text Field single line type)
- Reviewer
- Tester

### 2. Configuration Setup

1. Copy the example configuration file:
   ```bash
   cp config/initializers/jira_update_fields.rb.example config/initializers/jira_update_fields.rb
   ```

2. Edit the configuration file and replace the example custom field IDs with your actual Jira custom field IDs:
   ```ruby
   JIRA_UPDATE_CF_MAP = {
     'entered_requirements_at' => 'customfield_YOUR_ID',
     'entered_discovery_at' => 'customfield_YOUR_ID',
     # ... etc
     'reviewer' => 'customfield_YOUR_ID',
     'tester' => 'customfield_YOUR_ID'
   }
   ```

### 3. Finding Custom Field IDs

To find your Jira custom field IDs:

1. Go to **Jira Administration** > **Issues** > **Custom fields**
2. Click on the custom field you want to configure
3. Look at the URL - it will contain the field ID
4. Convert the ID format: if URL shows `id=10100`, use `customfield_10100`

Example URL: `.../secure/admin/EditCustomField!default.jspa?id=10100`
Custom Field ID: `customfield_10100`

## Usage

### Update All Issues

Update all issues in Jira with local data:
```bash
rails jira:update_jira_all
```

This will:
- Process all issues in the local database
- Update Jira custom fields with timestamp data
- Update Jira custom fields with reviewer/tester data
- Log success/failure for each issue

### Update Only Timestamps

Update only the `entered_..._at` timestamp fields:
```bash
rails jira:update_jira_timestamps
```

This will:
- Find all issues with timestamp data
- Update only timestamp custom fields in Jira
- Skip issues without timestamp data

### Update Only Reviewer/Tester

Update only the reviewer and tester fields:
```bash
rails jira:update_jira_reviewer_tester
```

This will:
- Find all issues with reviewer or tester data
- Update only reviewer/tester custom fields in Jira
- Skip issues without reviewer/tester data

### Update Specific Issue

Update a specific issue by key:
```bash
rails jira:update_jira_issue[ISSUE-123]
```

This will:
- Find the issue by key
- Update all relevant custom fields in Jira
- Log success/failure for the operation

## Programmatic Usage

### Update All Issues
```ruby
JiraUpdater.update_all
```

### Update Timestamps Only
```ruby
JiraUpdater.update_timestamps
```

### Update Reviewer/Tester Only
```ruby
JiraUpdater.update_reviewer_tester
```

### Update Specific Issue
```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")
JiraUpdater.update_issue(issue)
```

## Implementation Details

### JiraUpdater Service

The service provides:
- **Field mapping**: Maps local columns to Jira custom field IDs
- **Data formatting**: Formats data appropriately for Jira API
- **Batch processing**: Efficiently processes multiple issues
- **Error handling**: Graceful handling of API failures
- **Logging**: Detailed logging of operations

### JiraClient Updates

The JiraClient now includes:
- **update_issue method**: PUT request to update Jira issue fields
- **Field validation**: Ensures fields are properly formatted
- **Error handling**: Proper HTTP error handling

### Data Formatting

- **Timestamps**: Converted to ISO 8601 format for Jira
- **Text fields**: Sent as plain text strings
- **Empty values**: Skipped to avoid unnecessary API calls

## Error Handling

### Common Issues

1. **Custom field not found**: Check custom field ID mapping
2. **Permission denied**: Ensure API user has edit permissions
3. **Invalid field type**: Ensure custom field types match data types
4. **Network errors**: Check Jira connectivity and credentials

### Logging

The system provides detailed logging:
```
[JiraUpdater] Processing issue ISSUE-123
[JiraUpdater] Successfully updated ISSUE-123 with customfield_10101, customfield_10102
[JiraUpdater] Failed to update ISSUE-456: Field 'customfield_10999' not found
```

### Graceful Failures

- Individual issue failures don't stop the batch process
- Failed updates are logged with detailed error messages
- Successful updates are confirmed in logs
- Process continues even if some issues fail

## Performance Considerations

### Batch Processing
- Issues are processed one at a time to respect API limits
- Each update is a single API call with multiple fields
- Failed issues are skipped to maintain progress

### API Rate Limiting
- Jira API rate limits are respected
- Consider running updates during low-traffic periods
- Monitor Jira performance during large updates

### Selective Updates
- Only fields with data are included in updates
- Empty/null values are skipped
- Use specific update commands for targeted updates

## Security Considerations

### API Credentials
- Ensure API token has appropriate permissions
- Use dedicated service account for automation
- Rotate API tokens regularly

### Field Permissions
- Verify custom fields are editable via API
- Check field-level permissions in Jira
- Test with individual issues before batch updates

## Monitoring and Validation

### Success Verification
```ruby
# Check if update was successful
issue = JiraIssue.find_by(key: "ISSUE-123")
JiraUpdater.update_issue(issue)

# Verify in Jira by checking the custom fields
```

### Batch Monitoring
```bash
# Monitor logs during batch updates
tail -f log/production.log | grep JiraUpdater
```

### Data Validation
- Compare local data with Jira custom fields after update
- Spot-check random issues for accuracy
- Verify timestamp formatting in Jira

## Troubleshooting

### Configuration Issues
1. Check `jira_update_fields.rb` exists and is properly configured
2. Verify custom field IDs are correct
3. Ensure custom fields exist in Jira

### API Issues
1. Test API connectivity with a single issue update
2. Check API token permissions
3. Verify Jira URL and credentials

### Data Issues
1. Check that issues have the data you're trying to update
2. Verify data formats (timestamps should be valid dates)
3. Ensure reviewer/tester names are properly formatted

## Example Workflow

1. **Setup**: Create custom fields in Jira and configure mapping
2. **Test**: Update a single issue to verify configuration
3. **Partial Update**: Update timestamps or reviewer/tester separately
4. **Full Update**: Run complete update for all issues
5. **Verify**: Check Jira to confirm updates were applied correctly
