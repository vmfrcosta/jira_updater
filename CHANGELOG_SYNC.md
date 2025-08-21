# Jira Changelog Sync

This document explains the new changelog synchronization functionality added to the Jira sync process.

## Overview

The Jira sync now includes comprehensive changelog information for each Jira issue, tracking all field changes, status transitions, and other modifications made to issues over time.

## Database Schema

### Tables Created

1. **`jira_changelogs`** - Stores changelog history entries
   - `jira_issue_id` - Foreign key to jira_issues
   - `history_id` - Unique Jira history ID
   - `author_account_id` - Jira user account ID
   - `author_display_name` - Jira user display name
   - `created_at_jira` - When the change was made in Jira
   - `raw` - Complete raw JSON from Jira API

2. **`jira_changelog_items`** - Stores individual field changes
   - `jira_changelog_id` - Foreign key to jira_changelogs
   - `field` - Field name that was changed
   - `fieldtype` - Type of field (jira, custom, etc.)
   - `from_value` - Previous value (raw)
   - `from_string` - Previous value (human readable)
   - `to_value` - New value (raw)
   - `to_string` - New value (human readable)

## Usage

### Regular Sync (includes changelog)

The regular sync now automatically includes changelog information:

```bash
rails jira:sync
```

This will:
- Fetch all issues matching your JQL query
- Include changelog data in the API response
- Store changelog information in the database
- Skip duplicate changelog entries

### Sync Changelog for Existing Issues

If you have existing issues without changelog data, you can sync them separately:

```bash
rails jira:sync_changelog
```

This will:
- Find all issues that don't have any changelog entries
- Fetch changelog data for each issue individually
- Store the changelog information

### API Access

You can include changelog information in API responses by adding the `include_changelog=true` parameter:

```
GET /api/v1/issues?include_changelog=true
GET /api/v1/issues/ISSUE-123?include_changelog=true
```

The changelog will be included as a `changelog` array in the response:

```json
{
  "id": 1,
  "key": "ISSUE-123",
  "summary": "Example Issue",
  "status": "In Progress",
  "changelog": [
    {
      "id": "10001",
      "author": {
        "account_id": "user123",
        "display_name": "John Doe"
      },
      "created_at": "2024-01-01T10:00:00.000+0000",
      "items": [
        {
          "field": "status",
          "fieldtype": "jira",
          "from": "To Do",
          "to": "In Progress"
        }
      ]
    }
  ]
}
```

## Implementation Details

### JiraClient Changes

- Added `expand=changelog` parameter to search API calls
- Added `get_changelog` method for fetching changelog for specific issues

### JiraSync Changes

- Modified `upsert_issue` to process changelog data
- Added `process_changelog` method to handle changelog parsing and storage
- Added `sync_changelog_for_existing_issues!` method for retroactive sync
- Added duplicate prevention using `history_id`

### API Controller Changes

- Modified `build_json` to optionally include changelog data
- Added `include_changelog` parameter support

## Performance Considerations

- Changelog data is only fetched when needed
- Duplicate entries are prevented using `history_id`
- API responses include changelog only when explicitly requested
- Existing issues without changelog can be synced separately

## Error Handling

- Individual changelog sync failures are logged but don't stop the process
- Network errors during changelog fetching are handled gracefully
- Invalid changelog data is skipped rather than causing failures
