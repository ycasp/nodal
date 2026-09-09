class Bo::PricingController < Bo::BaseController
  def index
    @tab = params[:tab] || 'product_discounts'

    # Load all tabs data (needed for counts in tabs)
    load_product_discounts
    load_client_tiers
    load_custom_pricing
    load_order_tiers
    load_promo_codes

    if params[:notification_id].present?
      @pending_notification = current_organisation.discount_email_notifications.pending.find_by(id: params[:notification_id])
    end

    authorize :pricing, :index?
  end

  private

  def load_product_discounts
    @product_discounts = policy_scope(current_organisation.product_discounts)
      .includes(:product, :category, :email_notification)
      .order(created_at: :desc)

    if params[:search].present? && @tab == 'product_discounts'
      search_term = "%#{params[:search]}%"
      @product_discounts = @product_discounts
        .left_joins(:product, :category)
        .where("unaccent(products.name) ILIKE unaccent(:q) OR unaccent(categories.name) ILIKE unaccent(:q)", q: search_term)
    end
  end

  def load_client_tiers
    @customer_discounts = policy_scope(current_organisation.customer_discounts)
      .includes(:customer, :customer_category, :email_notification)
      .order(created_at: :desc)

    if params[:search].present? && @tab == 'client_tiers'
      @customer_discounts = @customer_discounts
        .left_joins(:customer, :customer_category)
        .where("unaccent(customers.company_name) ILIKE unaccent(:q) OR unaccent(customer_categories.name) ILIKE unaccent(:q)", q: "%#{params[:search]}%")
    end
  end

  def load_custom_pricing
    @custom_pricing = policy_scope(current_organisation.customer_product_discounts)
      .includes(:customer, :customer_category, :product, :category, :email_notification)
      .order(created_at: :desc)

    if params[:search].present? && @tab == 'custom_pricing'
      search_term = "%#{params[:search]}%"
      @custom_pricing = @custom_pricing
        .left_joins(:customer, :customer_category, :product, :category)
        .where("unaccent(customers.company_name) ILIKE unaccent(:q) OR unaccent(customer_categories.name) ILIKE unaccent(:q) OR unaccent(products.name) ILIKE unaccent(:q) OR unaccent(categories.name) ILIKE unaccent(:q)", q: search_term)
    end
  end

  def load_order_tiers
    @order_discounts = policy_scope(current_organisation.order_discounts)
      .includes(:email_notification)
      .order(min_order_amount_cents: :asc)
  end

  def load_promo_codes
    @promo_codes = policy_scope(current_organisation.promo_codes)
      .includes(:email_notification)
      .order(created_at: :desc)

    if params[:search].present? && @tab == 'promo_codes'
      @promo_codes = @promo_codes.where("unaccent(code) ILIKE unaccent(?)", "%#{params[:search]}%")
    end
  end
end
