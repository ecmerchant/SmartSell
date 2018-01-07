Rails.application.routes.draw do

  root to: 'items#show'

  get 'items/show'
  get 'items', to: 'items#show'

  post 'items/search'

  get 'items/setup'
  post 'items/setup'

  post 'items/upload'

  post 'items/connect'

  post 'items/reload'

  post 'items/save'

  get 'items/regist'
  post 'items/regist'

  devise_scope :user do
    get '/users/sign_out' => 'devise/sessions#destroy'
  end

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
