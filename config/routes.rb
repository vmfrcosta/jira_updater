Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Dashboard routes
  get "dashboard" => "dashboard#index"
  get "dashboard/json" => "dashboard#json_dashboard"
  get "dashboard/api" => "dashboard#api_metrics"
  get "dashboard/export" => "dashboard#export_csv"
  get "dashboard/export_raw_data" => "dashboard#export_raw_data"
  get "dashboard/issues_to_review" => "dashboard#issues_to_review"
  
  # Stories routes
  get "stories" => "stories#index"
  get "stories/api" => "stories#api_stories"
  
  # Jira sync route
  post "jira/sync" => "jira#sync"

  # Defines the root path route ("/")
  root "dashboard#index"
  
  namespace :api do
    namespace :v1 do
      resources :issues, only: [:index, :show]   # /api/v1/issues(.json|.csv)
    end
  end
end
