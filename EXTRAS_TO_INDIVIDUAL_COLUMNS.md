# Migration from Extras Column to Individual Columns

This document explains the changes made to remove the `extras` jsonb column and replace it with individual columns for better data structure and querying capabilities.

## Changes Made

### 1. Database Schema Changes

**Removed:**
- `extras` jsonb column from `jira_issues` table
- Index on `extras` column

**Added Individual Columns:**
- `points` (integer)
- `transitions_count` (integer)
- `entered_requirements_at` (datetime)
- `entered_discovery_at` (datetime)
- `entered_ideation_at` (datetime)
- `entered_validation_at` (datetime)
- `entered_refinement_at` (datetime)
- `entered_ready_for_dev_at` (datetime)
- `entered_ready_for_review_at` (datetime)
- `entered_ready_for_test_at` (datetime)
- `entered_ready_for_deploy_at` (datetime)
- `entered_developing_at` (datetime)
- `entered_reviewing_at` (datetime)
- `entered_testing_at` (datetime)
- `entered_deployed_at` (datetime)
- `entered_wrapup_at` (datetime)
- `entered_done_at` (datetime)

### 2. Model Changes

**JiraIssue Model:**
- Removed `store_accessor :extras` declaration
- Individual columns are now directly accessible as attributes
- No changes to associations or scopes

### 3. Service Changes

**JiraSync Service:**
- Modified `upsert_issue` method to use individual columns instead of extras hash
- Added `extract_individual_fields` method to map custom fields to individual columns
- Updated logging to show individual field values instead of extras

### 4. API Controller Changes

**IssuesController:**
- Modified `build_json` method to include individual columns directly
- Updated `to_csv` method to include all individual columns in CSV export
- Removed dependency on `extras` hash

### 5. Migration Strategy

**Migration File:**
- Created `20250821045052_remove_extras_and_add_individual_columns.rb`
- Removes extras column and index
- Adds all individual columns in a single migration

## Benefits

1. **Better Performance:** Direct column access is faster than JSON queries
2. **Type Safety:** Each column has a specific data type
3. **Easier Querying:** Can use standard SQL WHERE clauses
4. **Indexing:** Can create indexes on individual columns
5. **Validation:** Can add validations on individual columns
6. **Clarity:** Schema is more explicit about what data is stored

## Usage Examples

### Before (with extras):
```ruby
issue.extras["points"]
issue.extras["entered_requirements_at"]
JiraIssue.where("extras->>'points' > ?", 5)
```

### After (with individual columns):
```ruby
issue.points
issue.entered_requirements_at
JiraIssue.where("points > ?", 5)
```

### API Response:
```json
{
  "id": 1,
  "key": "ISSUE-123",
  "summary": "Example Issue",
  "points": 5,
  "transitions_count": 3,
  "entered_requirements_at": "2024-01-01T10:00:00Z",
  "entered_discovery_at": "2024-01-02T10:00:00Z"
}
```

## Migration Notes

- The migration is designed to be run on a fresh database
- If you have existing data in the extras column, you'll need to create a data migration script
- All existing functionality remains the same from an API perspective
- The changelog functionality is unaffected by these changes

## Testing

To verify the changes work correctly:

1. Run `rails db:migrate` to apply the migration
2. Test creating a new JiraIssue with individual column values
3. Test API responses include individual columns
4. Test CSV export includes individual columns
5. Test JiraSync still works with the new structure
