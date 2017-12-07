Rails.application.routes.draw do

  root to: 'items#show'

  get 'items/show'
  get 'items', to: 'items#show'

  post 'items/search'

  get 'items/setup'

  post 'items/connect'

  get 'items/regist'
  post 'items/regist'

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
