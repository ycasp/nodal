class Bo::PricingController < Bo::BaseController
  def index
    @tab = params[:tab] || 'product_discounts'

    case @tab
    when 'product_discounts'
      load_product_discounts
    when 'client_tiers'
      load_client_tiers
    when 'custom_pricing'
      load_custom_pricing
    end

    authorize :pricing, :index?
  end

  private

  def load_product_discounts
    @product_discounts = current_organisation.product_discounts
      .includes(:product)
      .order(created_at: :desc)

    if params[:search].present?
      @product_discounts = @product_discounts.joins(:product)
        .where("products.name ILIKE ?", "%#{params[:search]}%")
    end
  end

  def load_client_tiers
    @customer_discounts = current_organisation.customer_discounts
      .includes(:customer)
      .order(created_at: :desc)

    if params[:search].present?
      @customer_discounts = @customer_discounts.joins(:customer)
        .where("customers.company_name ILIKE ?", "%#{params[:search]}%")
    end
  end

  def load_custom_pricing
    @custom_pricing = current_organisation.customer_product_discounts
      .includes(:customer, :product)
      .order(created_at: :desc)

    if params[:search].present?
      @custom_pricing = @custom_pricing.joins(:customer, :product)
        .where("customers.company_name ILIKE ? OR products.name ILIKE ?",
               "%#{params[:search]}%", "%#{params[:search]}%")
    end
  end
end
