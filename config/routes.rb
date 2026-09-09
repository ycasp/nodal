Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Custom-domain mount — when request.host is some org's custom_domain,
  # storefront routes work without the slug prefix (e.g. b2b.cliente.pt/products).
  # Defined BEFORE the canonical root so b2b.cliente.pt/ resolves to the org's
  # storefront home rather than the Nodal marketing landing.
  constraints CustomDomainConstraint.new do
    # BO never serves from a custom host. Redirect both shapes to canonical.
    match ':org_slug/bo(/*path)', via: :all, to: redirect { |params, req|
      scheme = req.ssl? ? "https" : "http"
      canonical = Rails.application.config.x.canonical_host
      tail = params[:path].present? ? "/#{params[:path]}" : ""
      "#{scheme}://#{canonical}/#{params[:org_slug]}/bo#{tail}"
    }
    match 'bo(/*path)', via: :all, to: redirect { |params, req|
      scheme = req.ssl? ? "https" : "http"
      canonical = Rails.application.config.x.canonical_host
      slug = Organisation.find_by_host(req.host)&.slug
      tail = params[:path].present? ? "/#{params[:path]}" : ""
      "#{scheme}://#{canonical}/#{slug}/bo#{tail}"
    }

    # Root on a custom host means the storefront landing, not Nodal marketing.
    root to: "storefront/home#show", as: :custom_host_root

    # Customer auth without slug — manually defined inside devise_scope so
    # they wire to the SAME warden scope (:customer_user) as the slug-based
    # devise_for below. Drawing devise_for inside `scope as: :custom_host`
    # would create a second Devise mapping (:custom_host_customer_user) and
    # break warden session sharing — a login on the custom host would write
    # to one scope while current_customer_user on /home would read the
    # other, producing an infinite sign_in ↔ /home redirect loop.
    devise_scope :customer_user do
      get    'customers/sign_in',             to: 'customer_users/sessions#new',     as: :custom_host_new_customer_user_session
      post   'customers/sign_in',             to: 'customer_users/sessions#create',  as: :custom_host_customer_user_session
      delete 'customers/sign_out',            to: 'customer_users/sessions#destroy', as: :custom_host_destroy_customer_user_session

      get    'customers/password/new',        to: 'customer_users/passwords#new',    as: :custom_host_new_customer_user_password
      get    'customers/password/edit',       to: 'customer_users/passwords#edit',   as: :custom_host_edit_customer_user_password
      post   'customers/password',            to: 'customer_users/passwords#create'
      patch  'customers/password',            to: 'customer_users/passwords#update', as: :custom_host_customer_user_password
      put    'customers/password',            to: 'customer_users/passwords#update'

      get    'customers/invitation/accept',   to: 'customer_users/invitations#edit',    as: :custom_host_accept_customer_user_invitation
      get    'customers/invitation/remove',   to: 'customer_users/invitations#destroy', as: :custom_host_remove_customer_user_invitation
      get    'customers/invitation/new',      to: 'customer_users/invitations#new',     as: :custom_host_new_customer_user_invitation
      post   'customers/invitation',          to: 'customer_users/invitations#create'
      patch  'customers/invitation',          to: 'customer_users/invitations#update',  as: :custom_host_customer_user_invitation
      put    'customers/invitation',          to: 'customer_users/invitations#update'
    end

    # Storefront without slug. Prefixed route names with `custom_host_` to
    # avoid collisions with the slug-based mount below — view/controller
    # helpers continue to point at the slug-based names by default.
    scope as: :custom_host do
      draw :storefront
    end
  end

  # Canonical-host root — Nodal marketing landing.
  root to: "pages#home"

  # routes for each organisation (slug-based — source of truth, always works)
  scope ":org_slug" do
    # Customer auth (login lives on CustomerUser; empresa is Customer).
    # path: "customers" preserves public URLs so existing bookmarks and
    # already-sent invitation/reset_password links keep working. Mounted
    # here in routes.rb (rather than inside storefront.rb) so the second
    # mount on the custom-domain block doesn't create a duplicate Devise
    # mapping — see the comment under devise_scope :customer_user above.
    devise_for :customer_users, skip: [:registrations],
                path: "customers",
                controllers: {
                  sessions: 'customer_users/sessions',
                  invitations: 'customer_users/invitations',
                  passwords: 'customer_users/passwords'
                }

    # routes for each organisation
    draw :storefront

    # bo routes
    devise_for :members, controllers: { sessions: "members/sessions" }
    namespace :bo do
      get "/", to: "dashboards#index"
      get "dashboards/metrics", to: "dashboards#metrics", as: :dashboards_metrics
      get "analytics", to: "analytics#index", as: :analytics
      get "business_card", to: "business_cards#show", as: :business_card
      resources :orders do
        collection do
          get :export
          get :export_items
          # Picking a line by SKU: the search feeds the type-ahead, the pricing
          # call fills in what this customer would pay once one is chosen. Both
          # are on the collection because the order may not exist yet (new).
          get :variant_search
          get :variant_pricing
        end
        member do
          get :download_pdf
          patch :apply_discount
          delete :remove_discount
          patch :set_shipping
          post :retry_push
        end
      end
      resources :customers do
        collection do
          get :export
        end
        member do
          get :logins_modal
        end
        resources :customer_users, only: [:new, :create, :edit, :update] do
          member do
            post :resend_invitation
            patch :toggle_active
            # Regenerates the Devise invite token without sending email and
            # surfaces the URL in a modal so admins can paste it into
            # WhatsApp / SMS / their own channel. Bypasses corporate email
            # filtering that holds our invitation messages in quarantine.
            post :share_invitation
          end
          resource :quick_access_token, only: [:show, :create, :destroy] do
            get :download
          end
        end
        resource :customer_assignment, only: [:create]
      end

      # "Faltas" — demand cut from carts by stock policies, surfaced for the BO
      # team to satisfy / dismiss. See Bo::UnmetDemandsController.
      resources :unmet_demands, only: [:index] do
        member do
          post :satisfy
          post :substitute
          post :dismiss
        end
      end

      # Sales rep impersonation — Member becomes the "current_customer" for a
      # specific empresa to place orders via storefront. See
      # Bo::ImpersonationsController and Storefront::BaseController.
      resource :impersonation, only: [:create, :destroy]

      # Personal carteira page for OrgMembers with is_sales_rep: true.
      namespace :sales_rep do
        get :carteira, to: "carteira#index"

        # Reps generate product catalog PDFs from their own page. Reuses
        # GenerateCatalogJob + CatalogPdfService; no admin products access.
        get  :catalog,           to: "catalog#new"
        post :catalog,           to: "catalog#create", as: nil
        get  :catalog_selection, to: "catalog#selection"
      end
      resources :customer_categories, except: [:index, :show] do
        member do
          post :add_customers
          delete :remove_customer
        end
      end
      resources :products do
        collection do
          get :export
          get :export_variants
          get :stock_control
          get :generate_catalog
          get :catalog_preview
          get :import
          post :import_mapping
          post :import_process
          get :add_products
          get :bulk_create
          post :bulk_create_process
          get :bulk_create_process, to: redirect { |params| "/#{params[:org_slug]}/bo/products/bulk_create" }
          get :bulk_photos
          post :bulk_photos_process
          get :catalog_selection
        end
        member do
          get :configure_variants
          patch :update_variant_configuration
          delete :delete_photo
          patch :set_main_photo
          get :related_products
          get :related_products_search
          patch :update_related_products
          patch :reorder_related_products
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
        resources :product_attribute_values, only: [:create]
      end

      # Unified Pricing section
      get 'pricing', to: 'pricing#index', as: :pricing

      resources :product_discounts, except: [:index, :show] do
        collection do
          get :variant_overrides
        end
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
        collection do
          get :variant_overrides
        end
        member do
          patch :toggle_active
        end
      end

      resources :order_discounts, except: [:index, :show] do
        member do
          patch :toggle_active
        end
      end

      resources :promo_codes, except: [:index, :show] do
        member do
          patch :toggle_active
        end
      end

      resources :discount_email_notifications, only: [] do
        member do
          post :send_email
          get :recipients
        end
      end

      # Profile & Settings
      resource :profile, only: [:edit, :update]
      resource :settings, only: [:edit, :update]
      resource :homepage_settings, only: [:edit, :update] do
        post :create_banner
        patch :update_banner
        patch :toggle_banner
        delete :destroy_banner
        post :add_featured_products
        delete :remove_featured_product
        post :add_featured_categories
        delete :remove_featured_category
        post :add_special_price_products
        delete :remove_special_price_product
      end

      # Email Settings
      resource :email_settings, only: [:edit, :update] do
        get :email_logs
      end

      # Automations (scheduled digests)
      resources :automations do
        member do
          post :run_now
          patch :toggle
        end
      end

      # Background Tasks
      resources :background_tasks, only: [:index, :show] do
        member do
          get :download
          patch :cancel
        end
      end

      # ERP Integration
      resource :erp_settings, only: [:edit, :update] do
        post :test_connection
        post :fetch_sample
        post :test_filter
        post :sync_now
        get :sync_logs
      end

      # Team Management
      resources :team_members, path: 'team', except: [:show] do
        member do
          post :resend_invitation
          patch :toggle_active
          # Admin-only carteira management for a sales rep:
          # GET shows the two-panel UI; POST bulk-applies add/remove based on
          # params[:action_type] ("add" or "remove") and customer_ids[].
          get :carteira
          post :update_carteira
        end
      end
    end

    # Invitation acceptance (outside bo namespace, no auth required)
    get 'invitations/:token/accept', to: 'members/invitations#show', as: :accept_invitation
    post 'invitations/:token/accept', to: 'members/invitations#create'
  end
end

# Install slug-less URL helper overrides now that the route table is fully
# populated. Called from here (rather than from an initializer) so that the
# install runs in every context — server, console, jobs, and tests — without
# depending on after_initialize/to_prepare timing quirks.
HostAwareUrlHelpers::Dispatcher.install!
