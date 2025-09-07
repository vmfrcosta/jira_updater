# Agile Dashboard Documentation

## Overview

The Agile Dashboard provides comprehensive metrics and visualizations for your agile development process. It displays key performance indicators (KPIs) grouped by weeks, helping teams track their progress and identify areas for improvement.

## Features

### 📊 **Core Metrics**
- **Cycle Time**: Time from "Ready for Dev" to "Done" (average days)
- **Lead Time**: Time from "Requirements" to "Done" (average days)
- **Throughput**: Number of issues completed in the period
- **Total Issues**: Number of issues created in the period
- **Total Effort**: Total story points completed
- **Total Bugs Solved**: Number of bugs resolved

### 📈 **Visualizations**
- **Cycle Time vs Lead Time Chart**: Line chart showing trends over time
- **Throughput by Week**: Bar chart showing completed issues per week
- **Effort by Assignee**: Doughnut chart showing story points per team member
- **Bugs by Assignee**: Doughnut chart showing bugs resolved per team member

### 📋 **Data Table**
- Weekly breakdown of all metrics
- Sortable and filterable data
- Export functionality

## Accessing the Dashboard

### Web Interface
```
http://localhost:3000/dashboard
```

### API Endpoints
```
GET /dashboard/api?start_date=2025-01-01&end_date=2025-12-31
GET /dashboard/export?start_date=2025-01-01&end_date=2025-12-31
```

## Metrics Definitions

### Cycle Time
- **Definition**: Average time from when work starts (Ready for Dev) to when it's completed (Done)
- **Calculation**: `(entered_done_at - entered_ready_for_dev_at) / number_of_issues`
- **Unit**: Days
- **Target**: Lower is better (typically 1-7 days)

### Lead Time
- **Definition**: Average time from when work is requested (Requirements) to when it's completed (Done)
- **Calculation**: `(entered_done_at - entered_requirements_at) / number_of_issues`
- **Unit**: Days
- **Target**: Lower is better (typically 1-14 days)

### Throughput
- **Definition**: Number of issues completed in a given period
- **Calculation**: Count of issues with `entered_done_at` in the period
- **Unit**: Issues per week
- **Target**: Consistent and predictable

### Effort
- **Definition**: Total story points completed in the period
- **Calculation**: Sum of `points` for completed issues
- **Unit**: Story points
- **Target**: Consistent velocity

### Bugs Solved
- **Definition**: Number of bug-type issues resolved
- **Calculation**: Count of issues with `issue_type = 'Bug'` and `entered_done_at` in period
- **Unit**: Bugs per week
- **Target**: Minimize bugs, maximize quality

## Data Sources

The dashboard uses data from the following Jira fields:

### Status Transitions
- `entered_requirements_at`: When issue entered Requirements status
- `entered_ready_for_dev_at`: When issue entered Ready for Dev status
- `entered_done_at`: When issue entered Done status

### Issue Properties
- `created_at`: When issue was created
- `points`: Story points/effort estimation
- `issue_type`: Type of issue (Story, Bug, Task, etc.)
- `assignee`: Person assigned to the issue

### Relationships
- `parent_key`: For subtask relationships
- `reviewer`: Person who reviewed the issue
- `tester`: Person who tested the issue

## Usage Examples

### Filtering by Date Range
```
/dashboard?start_date=2025-08-01&end_date=2025-08-31
```

### API Response Format
```json
{
  "weekly_metrics": [
    {
      "week_start": "2025-08-18",
      "week_end": "2025-08-24",
      "week_label": "Aug 18 - Aug 24, 2025",
      "metrics": {
        "cycle_time": 0.7,
        "lead_time": 0,
        "throughput": 4,
        "total_issues": 83,
        "total_effort": 6,
        "effort_by_assignee": {
          "Ewerton Igor": 6,
          "Unassigned": 0
        },
        "total_bugs_solved": 2,
        "bugs_by_assignee": {
          "Ewerton Igor": 1,
          "Pedro Henrique Lima Silva": 1
        }
      }
    }
  ],
  "overall_metrics": {
    "cycle_time": 1.0,
    "lead_time": 3.0,
    "throughput": 7,
    "total_issues": 83,
    "total_effort": 11,
    "effort_by_assignee": {
      "Ewerton Igor": 6,
      "Pedro Henrique Lima Silva": 0,
      "Unassigned": 5,
      "Vinicius Alves": 0
    },
    "total_bugs_solved": 3,
    "bugs_by_assignee": {
      "Ewerton Igor": 1,
      "Pedro Henrique Lima Silva": 1,
      "Vinicius Alves": 1
    }
  }
}
```

## Testing

### Rake Task
```bash
# Test metrics calculation
bin/rails jira:test_agile_metrics
```

### Manual Testing
```ruby
# In Rails console
metrics_service = AgileMetricsService.new(4.weeks.ago, Time.current)
overall = metrics_service.overall_metrics
weekly = metrics_service.weekly_metrics
```

## Configuration

### Date Range
- **Default**: Last 12 weeks
- **Customizable**: Via URL parameters or API calls
- **Format**: YYYY-MM-DD

### Status Mapping
The dashboard uses these Jira status transitions:
- Requirements: `entered_requirements_at`
- Ready for Dev: `entered_ready_for_dev_at`
- Done: `entered_done_at`

### Issue Types
- **Bugs**: `issue_type = 'Bug'` or `'bug'`
- **All Issues**: All issue types are included in general metrics

## Performance Considerations

### Data Processing
- Metrics are calculated on-demand
- Large date ranges may take longer to process
- Consider caching for frequently accessed data

### Database Queries
- Uses efficient ActiveRecord queries
- Leverages database indexes on date fields
- Groups data by week for optimal performance

## Troubleshooting

### No Data Showing
1. Check if Jira sync has been run recently
2. Verify that status transitions are being captured
3. Ensure date range includes data

### Incorrect Metrics
1. Verify Jira status names match your workflow
2. Check that story points are being captured
3. Ensure assignee information is up to date

### Performance Issues
1. Reduce date range for testing
2. Check database indexes
3. Monitor server resources

## Future Enhancements

### Planned Features
- **Burndown Charts**: Sprint progress visualization
- **Velocity Tracking**: Team capacity planning
- **Quality Metrics**: Defect density, rework rates
- **Team Performance**: Individual contributor metrics
- **Predictive Analytics**: Forecasting based on historical data

### Customization Options
- **Custom Status Mappings**: Support for different workflows
- **Team Filtering**: Filter by specific teams or projects
- **Export Formats**: PDF, Excel, additional chart types
- **Real-time Updates**: WebSocket integration for live data

## API Documentation

### Endpoints

#### GET /dashboard/api
Returns JSON data for the dashboard.

**Parameters:**
- `start_date` (optional): Start date in YYYY-MM-DD format
- `end_date` (optional): End date in YYYY-MM-DD format

**Response:** JSON object with weekly and overall metrics

#### GET /dashboard/export
Returns CSV export of weekly metrics.

**Parameters:**
- `start_date` (optional): Start date in YYYY-MM-DD format
- `end_date` (optional): End date in YYYY-MM-DD format

**Response:** CSV file download

### Error Handling
- Invalid dates return 400 Bad Request
- No data returns empty arrays/objects
- Server errors return 500 Internal Server Error
