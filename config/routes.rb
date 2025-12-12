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
