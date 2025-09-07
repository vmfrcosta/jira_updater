class StoriesController < ApplicationController
  def index
    @stories = JiraIssue.where(issue_type: ['Story', 'story'])
                       .order(:status, :priority, :key)
  end

  def api_stories
    # Debug: Log the parameters being received
    Rails.logger.info "Stories API called with params: #{params.permit(:status, :priority, :issue_type, :br_us, :effort, :done, :refinement_date, :deploy_date, :sort_column, :sort_direction).to_h}"
    
    # Build the base query - include all issue types except epics
    stories = JiraIssue.where.not(issue_type: ['Epic', 'epic'])
                      .select(:key, :summary, :status, :priority, :issue_type, :br_us, :entered_ready_for_dev_at, :points, :entered_deployed_at, :refinement_projected_date, :deploy_projected_date, :children_count)
    
    # Apply filters
    stories = apply_filters(stories)
    
    # Get stories data first
    stories_data = stories.map do |story|
      {
        key: story.key,
        title: story.summary,
        status: story.status,
        priority: story.priority,
        issue_type: story.issue_type,
        br_us: story.br_us,
        refinement_date: format_date_with_fallback(story.entered_ready_for_dev_at, story.refinement_projected_date),
        effort: story.points,
        deploy_date: format_date_with_fallback(story.entered_deployed_at, story.deploy_projected_date),
        is_done: story.entered_deployed_at.present?,
        children_count: story.children_count || 0
      }
    end
    
    # Apply sorting to the data array
    stories_data = apply_sorting_to_data(stories_data)

    render json: {
      stories: stories_data,
      jira_base_url: ENV.fetch("JIRA_BASE_URL", "https://jira.company.com")
    }
  end

  private

  def apply_filters(stories)
    Rails.logger.info "Applying filters - status: '#{params[:status]}', present?: #{params[:status].present?}"
    
    # Status filter
    if params[:status].present?
      stories = stories.where(status: params[:status])
    end

    # Priority filter
    if params[:priority].present?
      stories = stories.where(priority: params[:priority])
    end

    # Issue type filter
    if params[:issue_type].present?
      stories = stories.where(issue_type: params[:issue_type])
    end

    # BR / US filter
    if params[:br_us].present?
      if params[:br_us] == 'no_value'
        stories = stories.where(br_us: [nil, '', 'Not Set'])
      else
        stories = stories.where(br_us: params[:br_us])
      end
    end



    # Effort filter
    if params[:effort].present?
      case params[:effort]
      when '1-3'
        stories = stories.where(points: 1..3)
      when '5-8'
        stories = stories.where(points: 5..8)
      when '13+'
        stories = stories.where('points >= ?', 13)
      end
    end

    # Done filter
    if params[:done].present?
      if params[:done] == 'true'
        stories = stories.where.not(entered_deployed_at: nil)
      elsif params[:done] == 'false'
        stories = stories.where(entered_deployed_at: nil)
      end
    end

    # Refinement date filter
    if params[:refinement_date].present?
      stories = stories.where("DATE(entered_ready_for_dev_at) = ?", params[:refinement_date])
    end

    # Deploy date filter
    if params[:deploy_date].present?
      case params[:deploy_date]
      when 'no_date'
        # No deploy date means neither actual nor projected date is set
        stories = stories.where(entered_deployed_at: nil, deploy_projected_date: nil)
      when 'has_date'
        # Has deploy date means either actual or projected date is set
        stories = stories.where("entered_deployed_at IS NOT NULL OR deploy_projected_date IS NOT NULL")
      else
        # Handle specific date filter (if needed in the future)
        stories = stories.where("DATE(entered_deployed_at) = ? OR DATE(deploy_projected_date) = ?", params[:deploy_date], params[:deploy_date])
      end
    end



    stories
  end

  def apply_sorting_to_data(stories_data)
    column = params[:sort_column]
    direction = params[:sort_direction] || 'asc'

    return stories_data unless column.present?

    case column
    when 'status'
      # Define status order (from lowest to highest priority)
      status_order = [
        'OPEN', 'REQUIREMENTS', 'DISCOVERY', 'IDEATION', 'VALIDATION', 'REFINEMENT',
        'READY FOR DEV', 'DEVELOPING', 'READY FOR REVIEW', 'REVIEWING', 
        'READY FOR TEST', 'TESTING', 'READY FOR DEPLOY', 'DEPLOYED', 'WRAP-UP', 'DONE'
      ]
      
      stories_data.sort_by! do |story|
        status_index = status_order.find_index(story[:status]) || status_order.length
        direction == 'asc' ? status_index : -status_index
      end
      
    when 'priority'
      # Define priority order (from highest to lowest priority)
      priority_order = ['Highest', 'High', 'Medium', 'Low']
      
      stories_data.sort_by! do |story|
        priority_index = priority_order.find_index(story[:priority]) || priority_order.length
        direction == 'asc' ? priority_index : -priority_index
      end
      
    when 'issue_type'
      stories_data.sort_by! do |story|
        issue_type = story[:issue_type] || ''
        direction == 'asc' ? issue_type : -issue_type.length
      end
      
    when 'br_us'
      stories_data.sort_by! do |story|
        br_us = story[:br_us] || ''
        direction == 'asc' ? br_us : -br_us.length
      end
      
    when 'refinement_date'
      stories_data.sort_by! do |story|
        date = story[:refinement_date] ? Date.parse(story[:refinement_date]) : Date.new(1900, 1, 1)
        direction == 'asc' ? date : -date.to_time.to_i
      end
      
    when 'effort'
      stories_data.sort_by! do |story|
        effort = story[:effort] || 0
        direction == 'asc' ? effort : -effort
      end
      
    when 'deploy_date'
      stories_data.sort_by! do |story|
        date = story[:deploy_date] ? Date.parse(story[:deploy_date]) : Date.new(1900, 1, 1)
        direction == 'asc' ? date : -date.to_time.to_i
      end
      
    when 'is_done'
      stories_data.sort_by! do |story|
        is_done = story[:is_done] ? 1 : 0
        direction == 'asc' ? is_done : -is_done
      end
      
    when 'children_count'
      stories_data.sort_by! do |story|
        children_count = story[:children_count] || 0
        direction == 'asc' ? children_count : -children_count
      end

    end

    stories_data
  end

  def format_date_with_fallback(primary_date, fallback_date)
    if primary_date.present?
      primary_date.strftime('%Y-%m-%d')
    elsif fallback_date.present?
      fallback_date.strftime('%Y-%m-%d')
    else
      nil
    end
  end
end
