class Bo::PromoCodesController < Bo::BaseController
  before_action :set_promo_code, only: [:edit, :update, :destroy, :toggle_active]

  def new
    @promo_code = PromoCode.new
    authorize @promo_code
    @customers = current_organisation.customers.order(:company_name)
    @customer_categories = current_organisation.customer_categories.ordered
  end

  def create
    @promo_code = PromoCode.new(promo_code_params)
    @promo_code.organisation = current_organisation
    authorize @promo_code

    if @promo_code.save
      notification = DiscountEmailNotification.create!(
        notifiable: @promo_code,
        organisation: current_organisation,
        status: 'pending',
        recipient_count: DiscountEmailNotification.recipient_count_for(@promo_code, current_organisation)
      )
      redirect_to bo_pricing_path(params[:org_slug], tab: 'promo_codes', notification_id: notification.id),
                  notice: t('bo.pricing.promo_codes.flash.created')
    else
      @customers = current_organisation.customers.order(:company_name)
      @customer_categories = current_organisation.customer_categories.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @customers = current_organisation.customers.order(:company_name)
    @customer_categories = current_organisation.customer_categories.ordered
  end

  def update
    if @promo_code.update(promo_code_params)
      redirect_to bo_pricing_path(params[:org_slug], tab: 'promo_codes'),
                  notice: t('bo.pricing.promo_codes.flash.updated')
    else
      @customers = current_organisation.customers.order(:company_name)
      @customer_categories = current_organisation.customer_categories.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @promo_code.destroy
    redirect_to bo_pricing_path(params[:org_slug], tab: 'promo_codes'),
                notice: t('bo.pricing.promo_codes.flash.deleted')
  end

  def toggle_active
    @promo_code.update(active: !@promo_code.active)
    redirect_to bo_pricing_path(params[:org_slug], tab: 'promo_codes'),
                notice: "Promo code #{@promo_code.active? ? 'activated' : 'deactivated'}."
  end

  private

  def set_promo_code
    @promo_code = current_organisation.promo_codes.find(params[:id])
    authorize @promo_code
  end

  def promo_code_params
    params.require(:promo_code).permit(
      :code, :description, :discount_type, :discount_value,
      :min_order_amount, :usage_limit, :per_customer_limit,
      :eligibility, :valid_from, :valid_until, :stackable, :active,
      eligible_customer_ids: [],
      eligible_customer_category_ids: []
    )
  end
end
