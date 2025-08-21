# Reviewer and Tester Population from Changelog

This document explains how the `reviewer` and `tester` columns are populated from changelog data by identifying the first person who moved an issue to the "Reviewing" and "Testing" statuses respectively.

## Overview

The system automatically populates the `reviewer` and `tester` columns by analyzing the changelog history and finding the first person (by timestamp) who moved an issue to the "Reviewing" and "Testing" statuses.

## Database Schema

### New Columns Added

- `reviewer` (string) - The display name of the first person who moved the issue to "Reviewing" status
- `tester` (string) - The display name of the first person who moved the issue to "Testing" status

## How It Works

### 1. Status Transition Detection
- Analyzes all changelog entries for an issue
- Identifies entries where `field = 'status'`
- Extracts `from_string`, `to_string`, and author information

### 2. First Person Identification
- For "Reviewing" status: Finds the changelog entry with the earliest `created_at_jira` timestamp where `to_string = 'Reviewing'`
- For "Testing" status: Finds the changelog entry with the earliest `created_at_jira` timestamp where `to_string = 'Testing'`

### 3. Column Population
- Updates the `reviewer` column with the `author_display_name` from the first "Reviewing" transition
- Updates the `tester` column with the `author_display_name` from the first "Testing" transition

## Usage

### Automatic Population
The reviewer and tester information is automatically populated during:
- Regular Jira sync (`rails jira:sync`)
- Changelog sync for existing issues (`rails jira:sync_changelog`)
- Full changelog population (`rails jira:populate_entered_timestamps`)

### Manual Population

#### Populate All Issues
```bash
rails jira:populate_reviewer_and_tester
```

#### Populate Specific Issue
```bash
rails jira:populate_issue_reviewer_tester[ISSUE-123]
```

### Programmatic Usage

#### Populate Single Issue
```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")
ChangelogPopulator.new.populate_reviewer_and_tester(issue)
```

#### Get Population Summary
```ruby
populator = ChangelogPopulator.new(issue)
summary = populator.get_population_summary
# Returns hash including reviewer and tester values
```

## Example Scenario

Consider an issue with the following changelog history:

1. **1 week ago**: To Do → Developing (John Developer)
2. **6 days ago**: Developing → Reviewing (Alice Reviewer)
3. **5 days ago**: Reviewing → Testing (Bob Tester)
4. **4 days ago**: Testing → Done (Charlie Manager)

The populated values would be:
- `reviewer`: "Alice Reviewer" (first person to move to Reviewing)
- `tester`: "Bob Tester" (first person to move to Testing)

## Implementation Details

### ChangelogPopulator Service Updates

The service now includes:
- **Author extraction**: Extracts author information from changelog entries
- **First person detection**: Finds the earliest status transition for specific statuses
- **Reviewer/Tester mapping**: Maps the first person to move to Reviewing/Testing statuses
- **Efficient updates**: Uses `update_columns` for direct database updates

### Performance Considerations

- Uses `includes` to avoid N+1 queries when loading changelog data
- Processes author information alongside timestamp data
- Uses `update_columns` for efficient bulk updates
- Logs progress for monitoring large operations

### Error Handling

- Skips issues with missing changelog data
- Handles cases where no Reviewing or Testing transitions exist
- Logs errors without stopping the entire process
- Continues processing even if individual issues fail

## API Integration

The reviewer and tester information is automatically included in API responses:

```json
{
  "id": 1,
  "key": "ISSUE-123",
  "summary": "Example Issue",
  "reviewer": "Alice Reviewer",
  "tester": "Bob Tester",
  "entered_reviewing_at": "2024-01-02T10:00:00Z",
  "entered_testing_at": "2024-01-03T10:00:00Z"
}
```

## CSV Export

The reviewer and tester columns are included in CSV exports:
- `reviewer` - The first person who moved the issue to Reviewing status
- `tester` - The first person who moved the issue to Testing status

## Monitoring and Logging

The service provides detailed logging:
- Progress updates for batch operations
- Success confirmations for each issue
- Specific reviewer and tester assignments
- Error messages for failed operations

Example log output:
```
[ChangelogPopulator] Set reviewer for ISSUE-123: Alice Reviewer
[ChangelogPopulator] Set tester for ISSUE-123: Bob Tester
```

## Edge Cases

### No Reviewing/Testing Transitions
- If an issue never reached "Reviewing" status, `reviewer` remains `null`
- If an issue never reached "Testing" status, `tester` remains `null`

### Multiple Transitions
- Only the first (earliest) transition to each status is considered
- Later transitions to the same status are ignored

### Missing Author Information
- If author information is missing from changelog entries, the corresponding field remains `null`
- The system logs warnings for missing author data

## Integration with Existing Features

### Changelog Sync
- Reviewer and tester population is integrated into the existing changelog sync process
- No additional steps required for new issues

### API Responses
- Reviewer and tester information is automatically included in all API responses
- No changes needed to existing API endpoints

### CSV Export
- Reviewer and tester columns are automatically included in CSV exports
- Maintains backward compatibility with existing export functionality
