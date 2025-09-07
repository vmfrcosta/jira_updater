class JiraController < ApplicationController
  def sync
    begin
      Rails.logger.info "Starting Jira sync..."
      
      # For now, just return success immediately and let the sync happen in background
      # This prevents the modal from hanging while sync is running
      Thread.new do
        begin
          Rails.logger.info "Starting background Jira sync..."
          jira_sync = JiraSync.new
          jira_sync.run!
          Rails.logger.info "Background Jira sync completed successfully"
        rescue => e
          Rails.logger.error "Background Jira sync failed: #{e.message}"
        end
      end
      
      render json: { 
        success: true, 
        message: "Jira sync started in background",
        timestamp: Time.current
      }
    rescue => e
      Rails.logger.error "Jira sync failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: { 
        success: false, 
        error: e.message,
        timestamp: Time.current
      }, status: 500
    end
  end
end
