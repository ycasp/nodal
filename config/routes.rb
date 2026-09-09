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
    # Locale switching
    patch 'locale', to: 'locales#update', as: :update_locale

    # customer routes
    devise_for :customers, skip: [:registrations],
                controllers: {
                  sessions: 'customers/sessions',
                  invitations: 'customers/invitations',
                  passwords: 'customers/passwords'
                }

    # storefront (customer-facing)
    scope module: :storefront do
      resource :contact, only: [:show]
      resources :products, only: [:index, :show]

      # Cart (current draft order)
      resource :cart, only: [:show] do
        delete :clear, on: :member
      end

      # Checkout
      resource :checkout, only: [:show, :update]

      # Order items (add/update/remove from cart)
      resources :order_items, only: [:create, :update, :destroy]

      # Order history (placed orders only)
      resources :orders, only: [:index, :show] do
        post :reorder, on: :member
      end
    end

    # bo routes
    devise_for :members, controllers: { sessions: "members/sessions" }
    namespace :bo do
      get "/", to: "dashboards#index"
      get "dashboards/metrics", to: "dashboards#metrics", as: :dashboards_metrics
      resources :orders do
        member do
          patch :apply_discount
          delete :remove_discount
        end
      end
      resources :customers do
        member do
          post :invite
        end
      end
      resources :products do
        collection do
          get :import
          post :import_mapping
          post :import_process
        end
        member do
          get :configure_variants
          patch :update_variant_configuration
          delete :delete_photo
        end
        resources :variants, controller: 'product_variants', except: [:show] do
          collection do
            post :generate
          end
        end
      end

      resources :categories do
        member do
          patch :move
          patch :restore
          post :add_products
          delete :remove_product
        end
        collection do
          patch :reorder
        end
      end

      resources :product_attributes do
        member do
          patch :restore
        end
        collection do
          patch :reorder
        end
      end

      # Unified Pricing section
      get 'pricing', to: 'pricing#index', as: :pricing

      resources :product_discounts, except: [:index, :show] do
        member do
          patch :toggle_active
        end
      end

      resources :customer_discounts, except: [:index, :show] do
        member do
          patch :toggle_active
        end
      end

      resources :customer_product_discounts, except: [:index, :show] do
        member do
          patch :toggle_active
        end
      end

      resources :order_discounts, except: [:index, :show] do
        member do
          patch :toggle_active
        end
      end

      # Profile & Settings
      resource :profile, only: [:edit, :update]
      resource :settings, only: [:edit, :update]

      # ERP Integration
      resource :erp_settings, only: [:edit, :update] do
        post :test_connection
        post :fetch_sample
        post :sync_now
        get :sync_logs
      end

      # Team Management
      resources :team_members, path: 'team', except: [:show] do
        member do
          post :resend_invitation
          patch :toggle_active
        end
      end
    end

    # Invitation acceptance (outside bo namespace, no auth required)
    get 'invitations/:token/accept', to: 'members/invitations#show', as: :accept_invitation
    post 'invitations/:token/accept', to: 'members/invitations#create'
  end
end
