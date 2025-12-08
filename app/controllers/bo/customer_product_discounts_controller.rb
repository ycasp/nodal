class Bo::CustomerProductDiscountsController < Bo::BaseController
  before_action :set_discount, only: [:edit, :update, :destroy]
  before_action :load_form_collections, only: [:new, :create, :edit, :update]

  def index
    @discounts = policy_scope(current_organisation.customer_product_discounts).includes(:customer, :product)
  end

  def new
    @discount = CustomerProductDiscount.new
    authorize @discount
  end

  def create
    @discount = CustomerProductDiscount.new(customer_product_discount_params)
    @discount.organisation = current_organisation
    authorize @discount

    if @discount.save
      redirect_to bo_customer_product_discounts_path(params[:org_slug]), notice: "Custom price created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @discount.update(customer_product_discount_params)
      redirect_to bo_customer_product_discounts_path(params[:org_slug]), notice: "Custom price updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @discount.destroy
    redirect_to bo_customer_product_discounts_path(params[:org_slug]), notice: "Custom price deleted successfully."
  end

  private

  def set_discount
    @discount = current_organisation.customer_product_discounts.find(params[:id])
    authorize @discount
  end

  def load_form_collections
    @customers = current_organisation.customers.order(:company_name)
    @products = current_organisation.products.order(:name)
  end

  def customer_product_discount_params
    params.require(:customer_product_discount).permit(:customer_id, :product_id, :discount_percentage, :valid_from, :valid_until)
  end
end
