class Storefront::ProductsController < Storefront::BaseController
  def index
    @products = policy_scope(current_organisation.products).includes(:category)
    @categories = current_organisation.categories

    if params[:category].present?
      @products = @products.where(category_id: params[:category])
    end

    if params[:query].present?
      query = "%#{params[:query]}%"
      @products = @products.where("name ILIKE ? OR description ILIKE ?", query, query)
    end

    @customer_discounts = current_customer&.active_discounts_for_products(@products.pluck(:id)) || {}
  end

  def show
    @product = current_organisation.products.find(params[:id])
    authorize @product
    @active_discount = @product.active_discount_for(current_customer)
  end
end
