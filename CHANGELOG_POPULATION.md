# Changelog Population for Entered Timestamps

This document explains how the `entered_..._at` columns are populated from changelog data using the oldest entries for each status.

## Overview

The system automatically populates the `entered_..._at` columns by analyzing the changelog history and finding the oldest (first) occurrence of each status transition. This provides accurate timestamps for when issues first entered each workflow stage.

## Status Mapping

The following status names are mapped to their corresponding `entered_..._at` columns:

| Status Name | Column Name |
|-------------|-------------|
| Requirements | `entered_requirements_at` |
| Discovery | `entered_discovery_at` |
| Ideation | `entered_ideation_at` |
| Validation | `entered_validation_at` |
| Refinement | `entered_refinement_at` |
| Ready for Dev | `entered_ready_for_dev_at` |
| Ready for Review | `entered_ready_for_review_at` |
| Ready for Test | `entered_ready_for_test_at` |
| Ready for Deploy | `entered_ready_for_deploy_at` |
| Developing | `entered_developing_at` |
| Reviewing | `entered_reviewing_at` |
| Testing | `entered_testing_at` |
| Deployed | `entered_deployed_at` |
| Wrap Up | `entered_wrapup_at` |
| Done | `entered_done_at` |

## How It Works

### 1. Status Transition Detection
- Analyzes all changelog entries for an issue
- Identifies entries where `field = 'status'`
- Extracts `from_string` and `to_string` values

### 2. Oldest Entry Selection
- Groups transitions by target status (`to_string`)
- For each status, finds the changelog entry with the earliest `created_at_jira` timestamp
- This represents the first time the issue entered that status

### 3. Column Population
- Updates the corresponding `entered_..._at` column with the oldest timestamp
- Uses `update_columns` for efficiency (bypasses validations and callbacks)

## Usage

### Automatic Population
The timestamps are automatically populated during:
- Regular Jira sync (`rails jira:sync`)
- Changelog sync for existing issues (`rails jira:sync_changelog`)

### Manual Population

#### Populate All Issues
```bash
rails jira:populate_entered_timestamps
```

#### Populate Specific Issue
```bash
rails jira:populate_issue_timestamps[ISSUE-123]
```

### Programmatic Usage

#### Populate Single Issue
```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")
ChangelogPopulator.populate_issue(issue)
```

#### Populate All Issues
```ruby
ChangelogPopulator.populate_all
```

#### Get Population Summary
```ruby
populator = ChangelogPopulator.new(issue)
summary = populator.get_population_summary
# Returns hash of populated columns and their values
```

## Example Scenario

Consider an issue with the following changelog history:

1. **1 week ago**: To Do → Requirements
2. **6 days ago**: Requirements → Discovery  
3. **5 days ago**: Discovery → Requirements
4. **4 days ago**: Requirements → Done

The populated timestamps would be:
- `entered_requirements_at`: 1 week ago (first time entering Requirements)
- `entered_discovery_at`: 6 days ago (first time entering Discovery)
- `entered_done_at`: 4 days ago (first time entering Done)

## Implementation Details

### ChangelogPopulator Service

The service provides:
- **Status mapping**: Maps Jira status names to column names
- **Transition analysis**: Extracts status transitions from changelog
- **Oldest entry detection**: Finds the earliest occurrence of each status
- **Batch processing**: Efficiently processes multiple issues
- **Error handling**: Graceful handling of missing or invalid data

### Performance Considerations

- Uses `includes` to avoid N+1 queries
- Uses `update_columns` for efficient bulk updates
- Processes issues in batches to manage memory usage
- Logs progress for monitoring large operations

### Error Handling

- Skips issues with missing changelog data
- Logs errors without stopping the entire process
- Handles malformed changelog entries gracefully
- Continues processing even if individual issues fail

## API Integration

The populated timestamps are automatically included in API responses:

```json
{
  "id": 1,
  "key": "ISSUE-123",
  "summary": "Example Issue",
  "entered_requirements_at": "2024-01-01T10:00:00Z",
  "entered_discovery_at": "2024-01-02T10:00:00Z",
  "entered_done_at": "2024-01-05T10:00:00Z"
}
```

## CSV Export

The timestamps are also included in CSV exports with columns:
- `entered_requirements_at`
- `entered_discovery_at`
- `entered_ideation_at`
- `entered_validation_at`
- `entered_refinement_at`
- `entered_ready_for_dev_at`
- `entered_ready_for_review_at`
- `entered_ready_for_test_at`
- `entered_ready_for_deploy_at`
- `entered_developing_at`
- `entered_reviewing_at`
- `entered_testing_at`
- `entered_deployed_at`
- `entered_wrapup_at`
- `entered_done_at`

## Monitoring and Logging

The service provides detailed logging:
- Progress updates for batch operations
- Success confirmations for each issue
- Error messages for failed operations
- Summary of populated columns

Example log output:
```
[ChangelogPopulator] Processing issue ISSUE-123
[ChangelogPopulator] Updated ISSUE-123 with: entered_requirements_at, entered_discovery_at, entered_done_at
```
