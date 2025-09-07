class AgileMetricsService
  def initialize(start_date = nil, end_date = nil)
    @start_date = start_date || 4.weeks.ago.beginning_of_week
    @end_date = end_date || Time.current.end_of_week
  end

  # Get metrics grouped by week
  def weekly_metrics
    weeks = generate_week_ranges
    weeks.map do |week_start, week_end|
      {
        week_start: week_start,
        week_end: week_end,
        week_label: format_week_label(week_start),
        metrics: calculate_week_metrics(week_start, week_end)
      }
    end
  end

  # Get overall metrics for the entire period
  def overall_metrics
    calculate_period_metrics(@start_date, @end_date)
  end

  private

  def generate_week_ranges
    weeks = []
    current_date = @start_date.beginning_of_week
    
    while current_date <= @end_date
      week_end = current_date.end_of_week
      weeks << [current_date, week_end]
      current_date = current_date + 1.week
    end
    
    weeks
  end

  def format_week_label(week_start)
    "#{week_start.strftime('%b %d')} - #{(week_start + 6.days).strftime('%b %d')}"
  end

  def calculate_week_metrics(week_start, week_end)
    {
      cycle_time: calculate_cycle_time(week_start, week_end),
      lead_time: calculate_lead_time(week_start, week_end),
      throughput: calculate_throughput(week_start, week_end),
      total_issues: calculate_total_issues(week_start, week_end),
      total_effort: calculate_total_effort(week_start, week_end),
      effort_by_assignee: calculate_effort_by_assignee(week_start, week_end),
      total_bugs_solved: calculate_total_bugs_solved(week_start, week_end),
      bugs_by_assignee: calculate_bugs_by_assignee(week_start, week_end),
      reviews_by_reviewer: calculate_reviews_by_reviewer(week_start, week_end),
      tests_by_tester: calculate_tests_by_tester(week_start, week_end)
    }
  end

  def calculate_period_metrics(start_date, end_date)
    {
      cycle_time: calculate_cycle_time(start_date, end_date),
      lead_time: calculate_lead_time(start_date, end_date),
      throughput: calculate_throughput(start_date, end_date),
      total_issues: calculate_total_issues(start_date, end_date),
      total_effort: calculate_total_effort(start_date, end_date),
      effort_by_assignee: calculate_effort_by_assignee(start_date, end_date),
      total_bugs_solved: calculate_total_bugs_solved(start_date, end_date),
      bugs_by_assignee: calculate_bugs_by_assignee(start_date, end_date),
      reviews_by_reviewer: calculate_reviews_by_reviewer(start_date, end_date),
      tests_by_tester: calculate_tests_by_tester(start_date, end_date)
    }
  end

  # Cycle Time: Time from "Developing" to "Deployed"
  def calculate_cycle_time(start_date, end_date)
    issues = JiraIssue.where(
        entered_developing_at: start_date..end_date,
        entered_deployed_at: start_date..end_date
    ).where.not(entered_developing_at: nil, entered_deployed_at: nil)

    return 0 if issues.empty?

    total_days = issues.sum do |issue|
      (issue.entered_deployed_at.to_date - issue.entered_developing_at.to_date).to_i
    end

    (total_days.to_f / issues.count).round(1)
  end

  # Lead Time: Time from "Requirements" to "Done"
  def calculate_lead_time(start_date, end_date)
    issues = JiraIssue.where(
      entered_requirements_at: start_date..end_date,
      entered_done_at: start_date..end_date
    ).where.not(entered_requirements_at: nil, entered_done_at: nil)

    return 0 if issues.empty?

    total_days = issues.sum do |issue|
      (issue.entered_done_at.to_date - issue.entered_requirements_at.to_date).to_i
    end

    (total_days.to_f / issues.count).round(1)
  end

  # Throughput: Number of issues completed in the period
  def calculate_throughput(start_date, end_date)
    JiraIssue.where(
      entered_deployed_at: start_date..end_date
    ).where.not(entered_deployed_at: nil).count
  end

  # Total issues created in the period
  def calculate_total_issues(start_date, end_date)
    JiraIssue.where(created_at: start_date..end_date).count
  end

  # Total effort (points) for tasks and subtasks completed in the period
  def calculate_total_effort(start_date, end_date)
    JiraIssue.where(
        issue_type: ['Task', 'Sub-task'],
        entered_deployed_at: start_date..end_date
    ).where.not(entered_deployed_at: nil, points: nil).sum(:points)
  end

  # Effort by assignee for tasks and subtasks completed in the period
  def calculate_effort_by_assignee(start_date, end_date)
    JiraIssue.where(
      issue_type: ['Task', 'Sub-task'],
      entered_deployed_at: start_date..end_date
    ).where.not(entered_deployed_at: nil, points: nil, assignee: nil)
    .group(:assignee)
    .sum(:points)
    .transform_keys { |k| k || 'Unassigned' }
  end

  # Total bugs solved in the period
  def calculate_total_bugs_solved(start_date, end_date)
    JiraIssue.where(
      issue_type: ['Bug', 'bug'],
      entered_deployed_at: start_date..end_date
    ).where.not(entered_deployed_at: nil).count
  end

  # Bugs by assignee for issues completed in the period
  def calculate_bugs_by_assignee(start_date, end_date)
    JiraIssue.where(
      issue_type: ['Bug', 'bug'],
      entered_deployed_at: start_date..end_date
    ).where.not(entered_deployed_at: nil, assignee: nil)
    .group(:assignee)
    .count
    .transform_keys { |k| k || 'Unassigned' }
  end

  # Reviews by reviewer for issues that entered reviewing status in the period
  def calculate_reviews_by_reviewer(start_date, end_date)
    JiraIssue.where(
      entered_reviewing_at: start_date..end_date
    ).where.not(entered_reviewing_at: nil, reviewer: nil)
    .group(:reviewer)
    .count
    .transform_keys { |k| k || 'Unassigned' }
  end

  # Tests by tester for issues that entered testing status in the period
  def calculate_tests_by_tester(start_date, end_date)
    JiraIssue.where(
      entered_testing_at: start_date..end_date
    ).where.not(entered_testing_at: nil, tester: nil)
    .group(:tester)
    .count
    .transform_keys { |k| k || 'Unassigned' }
  end

  # Helper method to get issues with their children (subtasks)
  def issues_with_children(start_date, end_date)
    parent_issues = JiraIssue.where(created_at: start_date..end_date)
    
    parent_issues.map do |parent|
      children = JiraIssue.where(parent_key: parent.key)
      {
        parent: parent,
        children: children,
        total_points: parent.points.to_i + children.sum(:points).to_i
      }
    end
  end

  # Calculate effort including subtasks
  def calculate_total_effort_with_subtasks(start_date, end_date)
    issues_with_children(start_date, end_date).sum { |issue_data| issue_data[:total_points] }
  end

  # Calculate effort by assignee including subtasks
  def calculate_effort_by_assignee_with_subtasks(start_date, end_date)
    effort_by_assignee = Hash.new(0)
    
    issues_with_children(start_date, end_date).each do |issue_data|
      parent = issue_data[:parent]
      children = issue_data[:children]
      
      # Add parent points to assignee
      if parent.assignee.present?
        effort_by_assignee[parent.assignee] += parent.points.to_i
      else
        effort_by_assignee['Unassigned'] += parent.points.to_i
      end
      
      # Add children points to their assignees
      children.each do |child|
        if child.assignee.present?
          effort_by_assignee[child.assignee] += child.points.to_i
        else
          effort_by_assignee['Unassigned'] += child.points.to_i
        end
      end
    end
    
    effort_by_assignee
  end
end
