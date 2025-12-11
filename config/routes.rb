Rails.application.routes.draw do
  resources :trucks
  root "home#index"

  get "dashboard", to: "dashboard#index"

  devise_for :users
end
