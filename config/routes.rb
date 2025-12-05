Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  root to: "pages#home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  # routes for each organisation
  scope ":org_slug" do
    # customer routes
    devise_for :customers, skip: [:registrations],
                controllers: { sessions: 'customers/sessions' }

    # storefront (customer-facing)
    scope module: :storefront do
      resources :products, only: [:index, :show]

      # Cart (current draft order)
      resource :cart, only: [:show] do
        delete :clear, on: :member
        post :place, on: :member
      end

      # Order items (add/update/remove from cart)
      resources :order_items, only: [:create, :update, :destroy]

      # Order history (placed orders only)
      resources :orders, only: [:index, :show]
    end

    # bo routes
    devise_for :members
    namespace :bo do
      get "/", to: "dashboards#dashview"
      resources :orders
      resources :customers do
        member do
          post :invite
        end
      end
      resources :products
    end
  end
end
