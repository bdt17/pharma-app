Rails.application.routes.draw do
  root "dashboard#index"

  get "/health", to: proc { [200, { "Content-Type" => "application/json" }, ['{"status":"ok"}']] }

  resources :regions
  resources :sites

  resources :trucks do
    post :send_test_alert, on: :member
  end

  resources :routes do
    member do
      post :optimize
      post :reorder_by_risk
      post :start
      post :complete
      post :add_waypoint
      delete :remove_waypoint
      post :mark_waypoint_arrived
      post :mark_waypoint_completed
    end
  end

  get "analytics", to: "analytics#index"
  get "analytics/summary", to: "analytics#summary"
  get "analytics/regions", to: "analytics#regions"
  get "analytics/sites", to: "analytics#sites"
  get "analytics/routes", to: "analytics#routes"
  get "analytics/excursions_over_time", to: "analytics#excursions_over_time"
  get "analytics/excursions_by_region", to: "analytics#excursions_by_region"

  namespace :api do
    namespace :v1 do
      resources :trucks do
        resources :monitorings, only: [:create]
      end
      resources :regions, only: [:index, :show]
      resources :sites, only: [:index, :show]
      resources :routes, only: [:index, :show, :create] do
        member do
          post :optimize
          post :reorder_by_risk
          get :suggestions
        end
      end
      get "trucks_by_risk", to: "trucks#by_risk"
      get "analytics/summary", to: "analytics#summary"
      get "analytics/regions", to: "analytics#regions"
      get "analytics/sites", to: "analytics#sites"
      get "analytics/routes", to: "analytics#routes"
    end
  end
end
