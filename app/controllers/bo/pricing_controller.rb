class Bo::PricingController < Bo::BaseController
  def index
    @tab = params[:tab] || 'product_discounts'

    # Load all tabs data (needed for counts in tabs)
    load_product_discounts
    load_client_tiers
    load_custom_pricing
    load_order_tiers

    authorize :pricing, :index?
  end

  private

  def load_product_discounts
    @product_discounts = policy_scope(current_organisation.product_discounts)
      .includes(:product)
      .order(created_at: :desc)

    if params[:search].present? && @tab == 'product_discounts'
      @product_discounts = @product_discounts.joins(:product)
        .where("products.name ILIKE ?", "%#{params[:search]}%")
    end
  end

  def load_client_tiers
    @customer_discounts = policy_scope(current_organisation.customer_discounts)
      .includes(:customer)
      .order(created_at: :desc)

    if params[:search].present? && @tab == 'client_tiers'
      @customer_discounts = @customer_discounts.joins(:customer)
        .where("customers.company_name ILIKE ?", "%#{params[:search]}%")
    end
  end

  def load_custom_pricing
    @custom_pricing = policy_scope(current_organisation.customer_product_discounts)
      .includes(:customer, :product)
      .order(created_at: :desc)

    if params[:search].present? && @tab == 'custom_pricing'
      @custom_pricing = @custom_pricing.joins(:customer, :product)
        .where("customers.company_name ILIKE ? OR products.name ILIKE ?",
               "%#{params[:search]}%", "%#{params[:search]}%")
    end
  end

  def load_order_tiers
    @order_discounts = policy_scope(current_organisation.order_discounts)
      .order(min_order_amount_cents: :asc)
  end
end
