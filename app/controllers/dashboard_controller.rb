class DashboardController < ApplicationController
  def index
    @start_date = params[:start_date]&.to_date || 4.weeks.ago.beginning_of_week
    @end_date = params[:end_date]&.to_date || Time.current.end_of_week
    
    begin
      @metrics_service = AgileMetricsService.new(@start_date, @end_date)
      @weekly_metrics = @metrics_service.weekly_metrics
      @overall_metrics = @metrics_service.overall_metrics
    rescue => e
      @error = e.message
      @weekly_metrics = []
      @overall_metrics = { cycle_time: 0, lead_time: 0, throughput: 0, total_issues: 0, total_effort: 0, total_bugs_solved: 0 }
    end
    
    render :index_basic, layout: false
  end

  def json_dashboard
    start_date = params[:start_date]&.to_date || 4.weeks.ago.beginning_of_week
    end_date = params[:end_date]&.to_date || Time.current.end_of_week
    
    begin
      metrics_service = AgileMetricsService.new(start_date, end_date)
      weekly_metrics = metrics_service.weekly_metrics
      overall_metrics = metrics_service.overall_metrics
    rescue => e
      render json: { error: e.message }, status: 500
      return
    end
    
    render json: {
      start_date: start_date,
      end_date: end_date,
      weekly_metrics: weekly_metrics,
      overall_metrics: overall_metrics
    }
  end

  def api_metrics
    start_date = params[:start_date]&.to_date || 12.weeks.ago.beginning_of_week
    end_date = params[:end_date]&.to_date || Time.current.end_of_week
    
    metrics_service = AgileMetricsService.new(start_date, end_date)
    
    render json: {
      weekly_metrics: metrics_service.weekly_metrics,
      overall_metrics: metrics_service.overall_metrics,
      date_range: {
        start_date: start_date,
        end_date: end_date
      }
    }
  end

  def export_csv
    start_date = params[:start_date]&.to_date || 4.weeks.ago.beginning_of_week
    end_date = params[:end_date]&.to_date || Time.current.end_of_week
    
    metrics_service = AgileMetricsService.new(start_date, end_date)
    weekly_metrics = metrics_service.weekly_metrics
    
    csv_data = generate_csv_data(weekly_metrics)
    
    send_data csv_data, 
              filename: "agile_metrics_#{start_date.strftime('%Y%m%d')}_#{end_date.strftime('%Y%m%d')}.csv",
              type: 'text/csv'
  end

  def issues_to_review
    # Find tasks and subtasks that are in developing or beyond status
    # but are missing assignee or story points
    issues = JiraIssue.where(issue_type: ['Task', 'Sub-task'])
                      .where.not(status: ['To Do', 'Backlog', 'Open'])
                      .where("status ILIKE '%developing%' OR status ILIKE '%review%' OR status ILIKE '%test%' OR status ILIKE '%done%' OR status ILIKE '%deployed%'")
                      .where("assignee IS NULL OR points IS NULL OR points = 0")
                      .select(:key, :summary, :issue_type, :status, :assignee, :points)
                      .order(:status, :key)
    
    # Convert to array of hashes for proper JSON serialization
    issues_data = issues.map do |issue|
      {
        issue_key: issue.key,
        summary: issue.summary,
        issue_type: issue.issue_type,
        status: issue.status,
        assignee: issue.assignee,
        story_points: issue.points
      }
    end
    
    render json: { 
      issues: issues_data,
      jira_base_url: ENV.fetch("JIRA_BASE_URL", "https://jira.company.com")
    }
  end

  def export_raw_data
    start_date = params[:start_date]&.to_date
    end_date = params[:end_date]&.to_date
    
    # Build the base query
    issues = JiraIssue.all
    
    # Apply date filters if provided
    if start_date
      issues = issues.where('created_at >= ?', start_date.beginning_of_day)
    end
    
    if end_date
      issues = issues.where('created_at <= ?', end_date.end_of_day)
    end
    
    # Order by created_at for consistent export
    issues = issues.order(:created_at)
    
    csv_data = generate_raw_csv_data(issues)
    
    filename = if start_date && end_date
      "jira_issues_raw_#{start_date.strftime('%Y%m%d')}_#{end_date.strftime('%Y%m%d')}.csv"
    elsif start_date
      "jira_issues_raw_from_#{start_date.strftime('%Y%m%d')}.csv"
    elsif end_date
      "jira_issues_raw_until_#{end_date.strftime('%Y%m%d')}.csv"
    else
      "jira_issues_raw_all.csv"
    end
    
    send_data csv_data, 
              filename: filename,
              type: 'text/csv; charset=utf-8'
  end

  private

  def generate_csv_data(weekly_metrics)
    require 'csv'
    
    # Collect all unique assignees, reviewers, and testers across all weeks
    all_assignees = Set.new
    all_reviewers = Set.new
    all_testers = Set.new
    
    weekly_metrics.each do |week_data|
      metrics = week_data[:metrics]
      all_assignees.merge(metrics[:effort_by_assignee]&.keys || [])
      all_assignees.merge(metrics[:bugs_by_assignee]&.keys || [])
      all_reviewers.merge(metrics[:reviews_by_reviewer]&.keys || [])
      all_testers.merge(metrics[:tests_by_tester]&.keys || [])
    end
    
    # Sort the names for consistent column ordering
    assignees_list = all_assignees.sort
    reviewers_list = all_reviewers.sort
    testers_list = all_testers.sort
    
    CSV.generate(headers: true, col_sep: ';') do |csv|
      # Build complete header row
      header_row = [
        'Week',
        'Cycle Time (days)',
        'Lead Time (days)',
        'Throughput',
        'Total Issues',
        'Total Effort (points)',
        'Total Bugs Solved'
      ]
      
      # Add effort by assignee headers
      assignees_list.each do |assignee|
        header_row << "Effort - #{assignee} (points)"
      end
      
      # Add bugs by assignee headers
      assignees_list.each do |assignee|
        header_row << "Bugs - #{assignee}"
      end
      
      # Add reviews by reviewer headers
      reviewers_list.each do |reviewer|
        header_row << "Reviews - #{reviewer}"
      end
      
      # Add tests by tester headers
      testers_list.each do |tester|
        header_row << "Tests - #{tester}"
      end
      
      csv << header_row
      
      # Data rows
      weekly_metrics.each do |week_data|
        metrics = week_data[:metrics]
        
        # Main metrics row
        data_row = [
          week_data[:week_label],
          format_decimal(metrics[:cycle_time]),
          format_decimal(metrics[:lead_time]),
          metrics[:throughput],
          metrics[:total_issues],
          metrics[:total_effort],
          metrics[:total_bugs_solved]
        ]
        
        # Add effort by assignee values
        assignees_list.each do |assignee|
          effort = metrics[:effort_by_assignee]&.dig(assignee) || 0
          data_row << effort
        end
        
        # Add bugs by assignee values
        assignees_list.each do |assignee|
          bugs = metrics[:bugs_by_assignee]&.dig(assignee) || 0
          data_row << bugs
        end
        
        # Add reviews by reviewer values
        reviewers_list.each do |reviewer|
          reviews = metrics[:reviews_by_reviewer]&.dig(reviewer) || 0
          data_row << reviews
        end
        
        # Add tests by tester values
        testers_list.each do |tester|
          tests = metrics[:tests_by_tester]&.dig(tester) || 0
          data_row << tests
        end
        
        csv << data_row
      end
    end
  end

  def generate_raw_csv_data(issues)
    require 'csv'
    
    # Add BOM for proper UTF-8 encoding
    bom = "\uFEFF"
    csv_content = CSV.generate(headers: true, col_sep: ';') do |csv|
      # Headers - include all relevant fields from jira_issue model
      csv << [
        'Issue Key',
        'Summary',
        'Issue Type',
        'Status',
        'Priority',
        'Assignee',
        'Story Points',
        'Sprint',
        'Parent Key',
        'Created At',
        'Updated At',
        'Entered Requirements At',
        'Entered Discovery At',
        'Entered Ideation At',
        'Entered Validation At',
        'Entered Refinement At',
        'Entered Ready for Dev At',
        'Entered Ready for Review At',
        'Entered Ready for Test At',
        'Entered Ready for Deploy At',
        'Entered Developing At',
        'Entered Reviewing At',
        'Entered Testing At',
        'Entered Deployed At',
        'Entered Wrapup At',
        'Entered Done At',
        'Reviewer',
        'Tester',
        'Refinement Projected Date',
        'Deploy Projected Date',
        'Project Key',
        'Start Date',
        'End Date',
        'Labels',
        'Transitions Count'
      ]
      
      # Data rows
      issues.each do |issue|
        csv << [
          issue.key,
          issue.summary,
          issue.issue_type,
          issue.status,
          issue.priority,
          issue.assignee,
          issue.points,
          issue.sprint,
          issue.parent_key,
          issue.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.updated_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_requirements_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_discovery_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_ideation_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_validation_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_refinement_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_ready_for_dev_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_ready_for_review_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_ready_for_test_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_ready_for_deploy_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_developing_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_reviewing_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_testing_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_deployed_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_wrapup_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.entered_done_at&.strftime('%Y-%m-%d %H:%M:%S'),
          issue.reviewer,
          issue.tester,
          issue.refinement_projected_date&.strftime('%Y-%m-%d'),
          issue.deploy_projected_date&.strftime('%Y-%m-%d'),
          issue.project_key,
          issue.start_date&.strftime('%Y-%m-%d'),
          issue.end_date&.strftime('%Y-%m-%d'),
          issue.labels,
          issue.transitions_count
        ]
      end
    end
    
    # Return CSV content with BOM
    bom + csv_content
  end

  def format_decimal(value)
    return 0 if value.nil?
    value.to_s.gsub('.', ',')
  end
end
