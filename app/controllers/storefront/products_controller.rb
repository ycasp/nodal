class Storefront::ProductsController < Storefront::BaseController
  def index
    @products = policy_scope(current_organisation.products).includes(:category, :product_discounts)
    @categories = current_organisation.categories

    if params[:category].present?
      @products = @products.where(category_id: params[:category])
    end

    if params[:query].present?
      query = "%#{params[:query]}%"
      @products = @products.where("name ILIKE ? OR description ILIKE ?", query, query)
    end

    # Build discount info for all products using DiscountCalculator
    # for_display: true shows all available discounts (ignoring min_quantity) for display purposes
    @product_discounts = @products.each_with_object({}) do |product, hash|
      calculator = DiscountCalculator.new(product: product, customer: current_customer, for_display: true)
      hash[product.id] = calculator.discount_breakdown
    end
  end

  def show
    @product = current_organisation.products.find(params[:id])
    authorize @product
    # for_display: true shows all available discounts (ignoring min_quantity) for display purposes
    @discount_calculator = DiscountCalculator.new(product: @product, customer: current_customer, for_display: true)
  end
end
