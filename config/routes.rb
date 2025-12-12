Rails.application.routes.draw do
  get "billing/new"
  get "billing/show"
  root "dashboard#index"

  # Health check endpoints (no auth)
  get "/health", to: "api/v1/health#show"
  get "/health/full", to: "api/v1/health#full"
  get "/health/ready", to: "api/v1/health#ready"
  get "/health/live", to: "api/v1/health#live"
  get "/health/metrics", to: "api/v1/health#metrics"

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

  get "console", to: "console#index"
  get "console/alerts", to: "console#alerts"
  get "console/live_data", to: "console#live_data"

  get "analytics", to: "analytics#index"
  get "analytics/summary", to: "analytics#summary"
  get "analytics/regions", to: "analytics#regions"
  get "analytics/states", to: "analytics#regions"
  get "analytics/sites", to: "analytics#sites"
  get "analytics/routes", to: "analytics#routes"
  get "analytics/excursions_over_time", to: "analytics#excursions_over_time"
  get "analytics/excursions_by_region", to: "analytics#excursions_by_region"

  namespace :api do
    namespace :v1 do
      resources :trucks do
        resources :monitorings, only: [:create]
        resources :telemetry, only: [:create, :index], controller: 'telemetry' do
          get :latest, on: :collection
        end
        resources :shipment_events, only: [:index, :create] do
          collection do
            get :chain_of_custody
            get :verify_chain
          end
        end
      end
      resources :regions, only: [:index, :show]
      resources :sites, only: [:index, :show]
      resources :routes, only: [:index, :show, :create] do
        collection do
          get :recommend
          get :compare
          get :early_warnings
        end
        member do
          post :optimize
          post :reorder_by_risk
          get :suggestions
          get :risk_assessment
          get :forecast
          get :history, to: 'shipment_events#route_history'
        end
      end
      get "trucks_by_risk", to: "trucks#by_risk"
      get "analytics/summary", to: "analytics#summary"
      get "analytics/regions", to: "analytics#regions"
      get "analytics/states", to: "analytics#regions"
      get "analytics/sites", to: "analytics#sites"
      get "analytics/routes", to: "analytics#routes"

      resources :simulations, only: [:index, :show, :create] do
        member do
          post :start
          post :pause
          get :replay
          get :events
        end
        collection do
          get :scenarios
        end
      end

      resources :warehouses, only: [:index, :show, :create] do
        member do
          post :check_in
          post :check_out
          get :handoff
          get :readings
          post :record_reading
          get :appointments
          post :create_appointment
        end
        collection do
          get :nearest
        end
        resources :storage_zones, only: [:index, :show, :create, :update] do
          member do
            get :inventory
            post :transfer
          end
        end
      end

      # Compliance endpoints
      scope :compliance do
        get 'verify/:route_id', to: 'compliance#verify_shipment', as: :verify_shipment
        get 'report/:route_id', to: 'compliance#report', as: :compliance_report
        get 'chain/:truck_id', to: 'compliance#verify_chain', as: :verify_chain
        post 'deviation/:event_id', to: 'compliance#deviation_report', as: :deviation_report
        get 'audit_trail', to: 'compliance#audit_trail', as: :audit_trail
        get 'records', to: 'compliance#records', as: :compliance_records
        get 'records/:id', to: 'compliance#show_record', as: :compliance_record
        post 'records/:id/approve', to: 'compliance#approve_record', as: :approve_record
        post 'records/:id/reject', to: 'compliance#reject_record', as: :reject_record
        post 'records/:id/evidence', to: 'compliance#add_evidence', as: :add_evidence
        get 'signatures', to: 'compliance#signatures', as: :signatures
        post 'signatures', to: 'compliance#create_signature', as: :create_signature
        get 'gdp_requirements', to: 'compliance#gdp_requirements', as: :gdp_requirements
      end

      # AI Integration endpoints
      scope :ai do
        get 'providers', to: 'ai#providers', as: :ai_providers
        post 'providers', to: 'ai#create_provider', as: :create_ai_provider
        patch 'providers/:id', to: 'ai#update_provider', as: :update_ai_provider

        get 'prompts', to: 'ai#prompts', as: :ai_prompts
        post 'prompts', to: 'ai#create_prompt', as: :create_ai_prompt
        patch 'prompts/:id', to: 'ai#update_prompt', as: :update_ai_prompt

        post 'analyze', to: 'ai#analyze', as: :ai_analyze
        post 'assess_risk', to: 'ai#assess_risk', as: :ai_assess_risk
        post 'optimize_route/:route_id', to: 'ai#optimize_route', as: :ai_optimize_route
        post 'detect_anomalies/:truck_id', to: 'ai#detect_anomalies', as: :ai_detect_anomalies
        post 'predict_temperature/:truck_id', to: 'ai#predict_temperature', as: :ai_predict_temperature
        post 'review_compliance/:route_id', to: 'ai#review_compliance', as: :ai_review_compliance

        get 'insights', to: 'ai#insights', as: :ai_insights
        get 'insights/:id', to: 'ai#show_insight', as: :ai_insight
        post 'insights/:id/acknowledge', to: 'ai#acknowledge_insight', as: :acknowledge_ai_insight
        post 'insights/:id/resolve', to: 'ai#resolve_insight', as: :resolve_ai_insight
        post 'insights/:id/dismiss', to: 'ai#dismiss_insight', as: :dismiss_ai_insight

        post 'feedback/:insight_id', to: 'ai#submit_feedback', as: :ai_feedback

        get 'requests', to: 'ai#requests', as: :ai_requests
        get 'stats', to: 'ai#stats', as: :ai_stats
        get 'types', to: 'ai#available_types', as: :ai_types
      end

      # Portal endpoints
      scope :portal do
        # Public tracking (no auth required)
        get 'track/:token', to: 'portal#track', as: :portal_track

        # Portal user management
        get 'users', to: 'portal#users', as: :portal_users
        get 'users/:id', to: 'portal#show_user', as: :portal_user
        post 'users', to: 'portal#create_user', as: :create_portal_user
        patch 'users/:id', to: 'portal#update_user', as: :update_portal_user
        post 'users/:id/regenerate_key', to: 'portal#regenerate_key', as: :regenerate_portal_key

        # Shipment sharing
        get 'shares', to: 'portal#shares', as: :portal_shares
        post 'shares', to: 'portal#create_share', as: :create_portal_share
        delete 'shares/:id', to: 'portal#revoke_share', as: :revoke_portal_share

        # Dashboards
        get 'dashboard/:user_id', to: 'portal#customer_dashboard', as: :customer_dashboard
        get 'analytics/:user_id', to: 'portal#partner_analytics', as: :partner_analytics

        # Webhooks
        get 'webhooks/:user_id', to: 'portal#webhooks', as: :portal_webhooks
        post 'webhooks/:user_id', to: 'portal#create_webhook', as: :create_portal_webhook
        patch 'webhooks/:id/update', to: 'portal#update_webhook', as: :update_portal_webhook
        delete 'webhooks/:id', to: 'portal#delete_webhook', as: :delete_portal_webhook
        post 'webhooks/:id/test', to: 'portal#test_webhook', as: :test_portal_webhook
        get 'webhook_events', to: 'portal#available_events', as: :webhook_events
      end

      # Batch processing endpoints
      scope :batch do
        post 'telemetry/:truck_id', to: 'batch#telemetry', as: :batch_telemetry
        post 'monitoring/:truck_id', to: 'batch#monitoring', as: :batch_monitoring
        post 'events/:truck_id', to: 'batch#events', as: :batch_events
        post 'warehouse_readings/:warehouse_id', to: 'batch#warehouse_readings', as: :batch_warehouse_readings
        post 'ai_analysis', to: 'batch#ai_analysis', as: :batch_ai_analysis
        get 'export', to: 'batch#export', as: :batch_export
      end
    end
  end

  get "simulations", to: "simulations#index"
  get "simulations/:id", to: "simulations#show", as: :simulation_detail

  resources :network_planning, only: [:index, :show, :new, :create] do
    member do
      post :approve
      post :reject
    end
    collection do
      get :demand_analysis
      get :lane_suggestions
      get :capacity_upgrades
      get :additional_carriers
      get :regional_summary
    end
  end

  mount ActionCable.server => "/cable"
end
get '/master', to: 'master_dashboard#index'
resources :billing, only: [:new, :show]
resources :billing, only: [:new, :success, :cancel]
