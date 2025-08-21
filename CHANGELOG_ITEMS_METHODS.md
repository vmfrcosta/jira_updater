# JiraIssue Changelog Items Methods

This document explains the new methods added to the `JiraIssue` model for accessing and filtering changelog items.

## Overview

The `JiraIssue` model now includes several methods to easily access and filter changelog items, providing a convenient way to analyze the history of changes for each issue.

## Available Methods

### 1. `changelog_items`

Returns all changelog items for the issue, ordered chronologically.

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")
all_items = issue.changelog_items
# Returns: ActiveRecord::Relation of JiraChangelogItem objects
# Ordered by: jira_changelogs.created_at_jira ASC, jira_changelog_items.created_at ASC
```

**Features:**
- Includes all changelog items for the issue
- Ordered chronologically by when the change occurred in Jira
- Includes all field changes (status, labels, description, etc.)

### 2. `changelog_items_unordered`

Returns all changelog items without ordering (useful for distinct operations).

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")
unordered_items = issue.changelog_items_unordered
# Returns: ActiveRecord::Relation without ORDER BY clause
```

**Use cases:**
- When you need to use `distinct` operations
- When you want to apply your own ordering
- For performance optimization when order doesn't matter

### 3. `changelog_items_by_field(field_name)`

Returns changelog items filtered by a specific field type.

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")

# Get all status changes
status_items = issue.changelog_items_by_field('status')

# Get all label changes
label_items = issue.changelog_items_by_field('labels')

# Get all description changes
description_items = issue.changelog_items_by_field('description')
```

**Parameters:**
- `field_name` (string): The field name to filter by (e.g., 'status', 'labels', 'description')

**Returns:** ActiveRecord::Relation filtered by the specified field

### 4. `status_changes`

Convenience method to get only status change changelog items.

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")
status_transitions = issue.status_changes

status_transitions.each do |change|
  puts "#{change.from_string} -> #{change.to_string}"
end
```

**Returns:** All changelog items where `field = 'status'`

### 5. `changelog_items_in_range(start_date, end_date)`

Returns changelog items within a specific date range.

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")

# Get changes in the last 30 days
end_date = Date.current
start_date = end_date - 30.days
recent_changes = issue.changelog_items_in_range(start_date, end_date)

# Get changes in a specific month
month_start = Date.new(2024, 1, 1)
month_end = Date.new(2024, 1, 31)
january_changes = issue.changelog_items_in_range(month_start, month_end)
```

**Parameters:**
- `start_date` (Date/DateTime): Start of the date range
- `end_date` (Date/DateTime): End of the date range

**Returns:** Changelog items where `jira_changelogs.created_at_jira` is within the specified range

## Usage Examples

### Basic Usage

```ruby
# Get an issue
issue = JiraIssue.find_by(key: "ISSUE-123")

# Get all changelog items
all_items = issue.changelog_items
puts "Total changes: #{all_items.count}"

# Display all changes
all_items.each do |item|
  puts "#{item.field}: #{item.from_string} -> #{item.to_string}"
end
```

### Status Analysis

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")

# Get status transitions
status_changes = issue.status_changes

puts "Status history for #{issue.key}:"
status_changes.each_with_index do |change, index|
  puts "#{index + 1}. #{change.from_string} -> #{change.to_string}"
end

# Find how long the issue was in each status
status_changes.each_cons(2) do |prev_change, next_change|
  duration = next_change.jira_changelog.created_at_jira - prev_change.jira_changelog.created_at_jira
  puts "#{prev_change.to_string}: #{duration.to_i / 3600} hours"
end
```

### Field-Specific Analysis

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")

# Get all field types that have been changed
field_types = issue.changelog_items_unordered.distinct.pluck(:field)
puts "Fields that have been modified: #{field_types.join(', ')}"

# Analyze label changes
label_changes = issue.changelog_items_by_field('labels')
puts "Label changes:"
label_changes.each do |change|
  puts "  #{change.from_string} -> #{change.to_string}"
end
```

### Date Range Analysis

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")

# Get changes in the last week
week_ago = 1.week.ago.to_date
today = Date.current
recent_changes = issue.changelog_items_in_range(week_ago, today)

puts "Changes in the last week: #{recent_changes.count}"

# Get changes by month
(1..12).each do |month|
  month_start = Date.new(2024, month, 1)
  month_end = month_start.end_of_month
  month_changes = issue.changelog_items_in_range(month_start, month_end)
  puts "#{month_start.strftime('%B')}: #{month_changes.count} changes"
end
```

### Advanced Filtering

```ruby
issue = JiraIssue.find_by(key: "ISSUE-123")

# Get status changes in the last month
month_ago = 1.month.ago.to_date
recent_status_changes = issue.status_changes
                              .joins(:jira_changelog)
                              .where(jira_changelogs: { 
                                created_at_jira: month_ago.beginning_of_day..Date.current.end_of_day 
                              })

puts "Status changes in the last month: #{recent_status_changes.count}"

# Get changes by specific user
user_changes = issue.changelog_items
                   .joins(:jira_changelog)
                   .where(jira_changelogs: { author_display_name: 'John Doe' })

puts "Changes by John Doe: #{user_changes.count}"
```

## Performance Considerations

### Efficient Queries

```ruby
# Good: Use includes to avoid N+1 queries
issues = JiraIssue.includes(:jira_changelogs => :jira_changelog_items)
issues.each do |issue|
  puts "#{issue.key}: #{issue.changelog_items.count} changes"
end

# Good: Use unordered version for distinct operations
field_types = issue.changelog_items_unordered.distinct.pluck(:field)

# Good: Use specific field filtering
status_changes = issue.status_changes  # More efficient than filtering manually
```

### Avoiding Common Pitfalls

```ruby
# Avoid: Don't use ordered relation with distinct.pluck
# This will cause PostgreSQL errors
field_types = issue.changelog_items.distinct.pluck(:field)  # ❌

# Use: Unordered version for distinct operations
field_types = issue.changelog_items_unordered.distinct.pluck(:field)  # ✅
```

## Integration with Existing Features

### With Changelog Population

```ruby
# After populating changelog data
issue = JiraIssue.find_by(key: "ISSUE-123")

# Verify population worked
if issue.changelog_items.any?
  puts "Changelog data is available"
  puts "First change: #{issue.changelog_items.first.field}"
else
  puts "No changelog data found"
end
```

### With API Responses

```ruby
# In API controllers, you can now easily include changelog data
def build_json(issue)
  base = {
    id: issue.id,
    key: issue.key,
    # ... other fields
  }

  if params[:include_changelog] == "true"
    base[:changelog_items] = issue.changelog_items.map do |item|
      {
        field: item.field,
        from: item.from_string,
        to: item.to_string,
        changed_at: item.jira_changelog.created_at_jira
      }
    end
  end

  base
end
```

## Error Handling

The methods handle common scenarios gracefully:

- **No changelog data**: Returns empty relation
- **Invalid field names**: Returns empty relation for `changelog_items_by_field`
- **Invalid date ranges**: Returns empty relation for `changelog_items_in_range`
- **Database errors**: Raises standard ActiveRecord exceptions

## Summary

These methods provide a comprehensive and efficient way to access and analyze changelog data for Jira issues, making it easy to:

- Track the complete history of changes
- Analyze status transitions and workflow patterns
- Filter changes by field type or date range
- Integrate changelog data into reports and analytics
- Build custom queries and analysis tools
