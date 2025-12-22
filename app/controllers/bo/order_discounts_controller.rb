class Bo::OrderDiscountsController < Bo::BaseController
  before_action :set_discount, only: [:edit, :update, :destroy, :toggle_active]

  def new
    @discount = OrderDiscount.new
    authorize @discount
  end

  def create
    @discount = OrderDiscount.new(order_discount_params)
    @discount.organisation = current_organisation
    authorize @discount

    if @discount.save
      CustomerMailer.with(discount: @discount, organisation: current_organisation).notify_clients_about_discount.deliver_later
      redirect_to bo_pricing_path(params[:org_slug], tab: 'order_tiers'),
                  notice: "Order discount created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @discount.update(order_discount_params)
      redirect_to bo_pricing_path(params[:org_slug], tab: 'order_tiers'),
                  notice: "Order discount updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @discount.destroy
    redirect_to bo_pricing_path(params[:org_slug], tab: 'order_tiers'),
                notice: "Order discount deleted successfully."
  end

  def toggle_active
    @discount.update(active: !@discount.active)
    redirect_to bo_pricing_path(params[:org_slug], tab: 'order_tiers'),
                notice: "Discount #{@discount.active? ? 'activated' : 'deactivated'}."
  end

  private

  def set_discount
    @discount = current_organisation.order_discounts.find(params[:id])
    authorize @discount
  end

  def order_discount_params
    params.require(:order_discount).permit(
      :discount_type, :discount_value, :min_order_amount,
      :valid_from, :valid_until, :stackable, :active
    )
  end
end
