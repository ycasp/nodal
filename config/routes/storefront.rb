# Storefront routes shared between the slug-based mount
# (nodal-seiri.dev/:org_slug/...) and the custom-domain mount
# (b2b.cliente.pt/...). Drawn from config/routes.rb via `draw :storefront`.
#
# Don't add BO, member auth, or invitation routes here — those belong only on
# the canonical host and stay in routes.rb.
#
# IMPORTANT — devise_for is NOT drawn here. Inside `scope as: :custom_host`,
# devise_for would create a second Devise mapping (:custom_host_customer_user)
# and the warden session written by a custom-host login wouldn't be visible
# to current_customer_user on subsequent requests, producing a sign-in →
# /home → sign_in redirect loop. The slug-based devise_for is mounted once
# in routes.rb under :org_slug; the custom-host equivalents are manually
# defined within devise_scope :customer_user so they share the same scope.

patch 'locale', to: 'locales#update', as: :update_locale

# Legal pages (public, no auth required)
scope module: :storefront do
  get 'terms', to: 'legal_pages#terms', as: :terms
  get 'privacy', to: 'legal_pages#privacy', as: :privacy
end

# Storefront (customer-facing)
scope module: :storefront do
  # Quick-access landing — scans of QR cards / stickers land here.
  # Validates the token, audits the scan, then redirects to the
  # CustomerUser sign-in page with the email pre-filled.
  get 'quick/:token', to: 'quick_access#show', as: :quick_access

  get 'home', to: 'home#show', as: :home
  resource :contact, only: [:show]
  resources :products, only: [:index, :show] do
    get :autocomplete, on: :collection
  end

  # Cart (current draft order)
  resource :cart, only: [:show] do
    delete :clear, on: :member
  end

  # Checkout
  resource :checkout, only: [:show, :update] do
    post :acknowledge_pricing, on: :member
  end

  # Promo codes (apply/remove at checkout)
  resource :promo_code, only: [] do
    post :apply
    delete :remove
  end

  # Order items (add/update/remove from cart)
  resources :order_items, only: [:create, :update, :destroy] do
    post :bulk_add, on: :collection
    # Scan-to-cart: resolve a scanned barcode (variant SKU) and add it to the
    # current cart. Used by sales reps on the cart page during impersonation.
    post :scan, on: :collection
  end

  # Order history (placed orders only)
  resources :orders, only: [:index, :show] do
    collection do
      get :export
      get :export_items
    end
    member do
      get :download_pdf
      post :reorder
      post :add_to_cart
    end
  end

  # Shopping lists
  resources :shopping_lists, except: [:edit] do
    member do
      post :add_to_cart
      get :product_picker
    end
    resources :shopping_list_items, only: [:create, :update, :destroy], as: :items
  end

  # Customer account settings
  resource :account, only: [:show, :update] do
    patch :toggle_hide_prices
  end
end
