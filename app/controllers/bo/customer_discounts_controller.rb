class Bo::CustomerDiscountsController < Bo::BaseController
  before_action :set_discount, only: [:edit, :update, :destroy, :toggle_active]
  before_action :load_form_collections, only: [:new, :create, :edit, :update]

  def new
    @discount = CustomerDiscount.new
    authorize @discount
  end

  def create
    @discount = CustomerDiscount.new(customer_discount_params)
    @discount.organisation = current_organisation
    authorize @discount

    if @discount.save
      CustomerMailer.with(discount: @discount, organisation: current_organisation).notify_customer_about_discount.deliver_later
      redirect_to bo_pricing_path(params[:org_slug], tab: 'client_tiers'),
                  notice: "Client tier discount created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @discount.update(customer_discount_params)
      redirect_to bo_pricing_path(params[:org_slug], tab: 'client_tiers'),
                  notice: "Client tier discount updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @discount.destroy
    redirect_to bo_pricing_path(params[:org_slug], tab: 'client_tiers'),
                notice: "Client tier discount deleted successfully."
  end

  def toggle_active
    @discount.update(active: !@discount.active)
    redirect_to bo_pricing_path(params[:org_slug], tab: 'client_tiers'),
                notice: "Discount #{@discount.active? ? 'activated' : 'deactivated'}."
  end

  private

  def set_discount
    @discount = current_organisation.customer_discounts.find(params[:id])
    authorize @discount
  end

  def load_form_collections
    @customers = current_organisation.customers.order(:company_name)
  end

  def customer_discount_params
    params.require(:customer_discount).permit(
      :customer_id, :discount_type, :discount_value,
      :valid_from, :valid_until, :stackable, :active, :notes
    )
  end
end
