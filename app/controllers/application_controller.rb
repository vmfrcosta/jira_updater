class ApplicationController < ActionController::API
    before_action :check_token!
  
    private
  
    def check_token!
      return if Rails.env.development? # <-- libera no dev
  
      expected = ENV["API_TOKEN"]
      return if expected.blank?
  
      auth = request.headers["Authorization"].to_s
      head :unauthorized unless auth == "Bearer #{expected}"
    end
  end
  