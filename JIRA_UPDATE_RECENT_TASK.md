# Jira Update Recent Issues Task

## Overview

The `jira:update_jira_recent` task updates all Jira issues that have been modified locally in the last N days and have timestamp, reviewer, or tester data to sync back to Jira.

## Usage

### Basic Usage (14 days default)
```bash
bin/rails jira:update_jira_recent
```

### Custom Time Period
```bash
# Update issues from the last 7 days
bin/rails "jira:update_jira_recent[7]"

# Update issues from the last 30 days
bin/rails "jira:update_jira_recent[30]"

# Update issues from the last 2 days
bin/rails "jira:update_jira_recent[2]"
```

## What It Does

1. **Finds Recent Issues**: Identifies all `JiraIssue` records that have been updated (`updated_at`) in the last N days
2. **Filters by Data**: Only includes issues that have:
   - Any timestamp data in the `entered_..._at` columns, OR
   - Reviewer or tester data
3. **Updates Jira**: Sends the local data back to Jira using the configured custom field mappings

## Example Output

```
Atualizando issues no Jira que foram atualizadas nos últimos 2 dias...
Atualização concluída. 79 issues atualizadas.
```

## Use Cases

### Daily Sync
```bash
# Run daily to keep Jira in sync with recent local changes
bin/rails "jira:update_jira_recent[1]"
```

### Weekly Sync
```bash
# Run weekly to catch any issues that might have been missed
bin/rails "jira:update_jira_recent[7]"
```

### After Major Data Population
```bash
# After running changelog population tasks, update all recent changes
bin/rails jira:populate_entered_timestamps
bin/rails jira:populate_reviewer_and_tester
bin/rails "jira:update_jira_recent[7]"
```

## Performance Considerations

- **Large Datasets**: If you have many issues updated recently, the task may take a while to complete
- **API Rate Limits**: The task makes one API call per issue, so be mindful of Jira API rate limits
- **Timeout**: For large updates, consider running with a longer timeout or breaking into smaller batches

## Error Handling

- The task logs each successful update
- Failed updates are logged as errors but don't stop the task
- The final count shows how many issues were successfully updated

## Configuration Requirements

Before using this task, ensure:

1. **Custom Fields Created**: All required custom fields exist in Jira
2. **Field Mappings Configured**: `config/initializers/jira_update_fields.rb` has correct custom field IDs
3. **Jira API Access**: Valid credentials configured for Jira API access

## Related Tasks

- `jira:update_jira_all` - Updates all issues (not just recent ones)
- `jira:update_jira_issue[KEY]` - Updates a specific issue
- `jira:update_jira_timestamps` - Updates only timestamp fields
- `jira:update_jira_reviewer_tester` - Updates only reviewer/tester fields

## Troubleshooting

### Task Hangs
If the task appears to hang, it's likely processing many issues. Try:
- Using a shorter time period: `bin/rails "jira:update_jira_recent[1]"`
- Running with timeout: `timeout 300 bin/rails "jira:update_jira_recent[7]"`

### No Issues Found
If no issues are updated, check:
- Are there any issues updated in the specified time period?
- Do those issues have timestamp, reviewer, or tester data?
- Are the custom field mappings configured correctly?

### API Errors
If you get API errors, check:
- Jira API credentials
- Custom field IDs in configuration
- Network connectivity to Jira
