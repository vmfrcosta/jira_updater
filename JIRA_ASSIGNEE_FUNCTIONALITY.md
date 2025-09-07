# Jira Assignee Functionality

## Overview

The system now captures and stores the assignee information for each Jira issue. This allows you to track who is responsible for each issue and filter/search by assignee.

## Database Schema

The `jira_issues` table now includes an `assignee` field:
- **Type**: `string`
- **Description**: Stores the assignee's display name for the issue
- **Nullable**: Yes (issues can be unassigned)

## How It Works

### 1. Data Capture
- The `JiraClient` fetches assignee information from Jira's API
- The `JiraSync` service extracts and stores the assignee data
- Assignee information is captured during regular sync operations

### 2. Data Extraction
The system extracts assignee information with the following priority:
1. `displayName` (preferred)
2. `name` (fallback)
3. `accountId` (last resort)

### 3. Storage
- Assignee names are stored as strings in the `assignee` field
- Unassigned issues have `assignee` set to `nil`

## Usage Examples

### Model Methods

```ruby
# Check if an issue has an assignee
issue.has_assignee?
# => true/false

# Check if an issue is unassigned
issue.unassigned?
# => true/false

# Get assignee name
issue.assignee
# => "John Doe" or nil
```

### Scopes for Filtering

```ruby
# Find all issues assigned to a specific person
JiraIssue.assigned_to("John Doe")

# Find all unassigned issues
JiraIssue.unassigned

# Find all assigned issues
JiraIssue.assigned
```

### API Usage

```ruby
# Get all issues assigned to a specific person
GET /api/v1/issues?assignee=John%20Doe

# Get all unassigned issues
GET /api/v1/issues?unassigned=true
```

## Rake Tasks

### Sync Assignees for Existing Issues
```bash
# Sync assignee information for all existing issues
bin/rails jira:sync_assignees
```

This task:
- Fetches fresh assignee data from Jira for each issue
- Updates the local database with current assignee information
- Shows progress and final count of updated issues

### Regular Sync (Includes Assignees)
```bash
# Regular sync now includes assignee information
bin/rails jira:sync
```

## Integration with Existing Features

### Recent Updates Task
The `jira:update_jira_recent` task now considers assignee changes when determining which issues to update.

### API Response
The API now includes assignee information in the response:
```json
{
  "key": "EPT-75",
  "summary": "Example Issue",
  "assignee": "Pedro Henrique Lima Silva",
  "status": "In Progress",
  // ... other fields
}
```

## Data Quality

### Assignee Names
- Full names are stored (e.g., "Pedro Henrique Lima Silva")
- Names are extracted from Jira's user information
- Consistent formatting across all issues

### Unassigned Issues
- Issues without assignees have `assignee` set to `nil`
- Can be easily filtered using the `unassigned` scope

## Performance Considerations

### Sync Performance
- Assignee sync processes issues one by one
- For large datasets, consider running with timeout: `timeout 300 bin/rails jira:sync_assignees`
- Regular sync includes assignee data automatically

### Query Performance
- The `assignee` field is indexed for efficient filtering
- Scopes like `assigned_to` and `unassigned` are optimized

## Troubleshooting

### Missing Assignee Data
If assignee information is missing:
1. Run `bin/rails jira:sync_assignees` to fetch fresh data
2. Check if the issue is actually assigned in Jira
3. Verify Jira API permissions for user data

### Sync Issues
If assignee sync fails:
1. Check Jira API connectivity
2. Verify API credentials have user read permissions
3. Check for rate limiting issues

## Future Enhancements

Potential improvements:
- Store assignee account ID alongside display name
- Track assignee change history in changelog
- Add assignee statistics and reporting
- Integrate with team management features
