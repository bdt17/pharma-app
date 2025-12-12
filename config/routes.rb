Rails.application.routes.draw do
  devise_for :users
  root 'home#index'

  resources :trucks
  resources :inventory, only: [:index]

  resource :billing, only: [:new] do
    get :success
    get :cancel
  end

  get '/master', to: 'master_dashboard#index'
end
# cache-bust 1765520860
# cache-bust 1765520983
