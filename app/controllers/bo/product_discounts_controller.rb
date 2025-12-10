class Bo::ProductDiscountsController < Bo::BaseController
  before_action :set_discount, only: [:edit, :update, :destroy, :toggle_active]
  before_action :load_form_collections, only: [:new, :create, :edit, :update]

  def new
    @discount = ProductDiscount.new
    authorize @discount
  end

  def create
    @discount = ProductDiscount.new(product_discount_params)
    @discount.organisation = current_organisation
    authorize @discount

    if @discount.save
      redirect_to bo_pricing_path(params[:org_slug], tab: 'product_discounts'),
                  notice: "Product discount created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @discount.update(product_discount_params)
      redirect_to bo_pricing_path(params[:org_slug], tab: 'product_discounts'),
                  notice: "Product discount updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @discount.destroy
    redirect_to bo_pricing_path(params[:org_slug], tab: 'product_discounts'),
                notice: "Product discount deleted successfully."
  end

  def toggle_active
    @discount.update(active: !@discount.active)
    redirect_to bo_pricing_path(params[:org_slug], tab: 'product_discounts'),
                notice: "Discount #{@discount.active? ? 'activated' : 'deactivated'}."
  end

  private

  def set_discount
    @discount = current_organisation.product_discounts.find(params[:id])
    authorize @discount
  end

  def load_form_collections
    @products = current_organisation.products.order(:name)
  end

  def product_discount_params
    params.require(:product_discount).permit(
      :product_id, :discount_type, :discount_value, :min_quantity,
      :valid_from, :valid_until, :stackable, :active
    )
  end
end
