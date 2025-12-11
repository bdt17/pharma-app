Rails.application.routes.draw do
  root "dashboard#index"

  resources :trucks do
    post :send_test_alert, on: :member
  end

  namespace :api do
    namespace :v1 do
      get "monitorings/create"
      resources :trucks do
        resources :monitorings, only: [:create]
      end
    end
  end
end
