class Bo::CustomerDiscountsController < Bo::BaseController
  before_action :set_discount, only: [:edit, :update, :destroy, :toggle_active]
  before_action :load_form_collections, only: [:new, :create, :edit, :update]

  def new
    @discount = CustomerDiscount.new
    authorize @discount
  end

  def create
    customer_ids = Array(params[:customer_ids]).reject(&:blank?)
    customer_category_ids = Array(params[:customer_category_ids]).reject(&:blank?)

    if customer_ids.empty? && customer_category_ids.empty?
      @discount = CustomerDiscount.new(customer_discount_params)
      @discount.organisation = current_organisation
      authorize @discount
      @discount.errors.add(:base, t('bo.pricing.client_tiers.select_at_least_one'))
      return render :new, status: :unprocessable_entity
    end

    @discount = CustomerDiscount.new(customer_discount_params.except(:customer_id, :customer_category_id))
    @discount.organisation = current_organisation
    @discount.customer_id = customer_ids.first if customer_ids.any?
    @discount.customer_category_id = customer_category_ids.first if customer_ids.empty? && customer_category_ids.any?
    authorize @discount

    created_discounts = []
    errors = []

    customer_ids.each do |cid|
      discount = CustomerDiscount.new(customer_discount_params.except(:customer_id, :customer_category_id))
      discount.organisation = current_organisation
      discount.customer_id = cid
      if discount.save
        created_discounts << discount
      else
        errors << discount.errors.full_messages
      end
    end

    customer_category_ids.each do |ccid|
      discount = CustomerDiscount.new(customer_discount_params.except(:customer_id, :customer_category_id))
      discount.organisation = current_organisation
      discount.customer_category_id = ccid
      if discount.save
        created_discounts << discount
      else
        errors << discount.errors.full_messages
      end
    end

    if created_discounts.any?
      total_recipients = created_discounts.sum do |d|
        DiscountEmailNotification.recipient_count_for(d, current_organisation)
      end

      # Create one notification per discount
      last_notification = nil
      created_discounts.each do |d|
        last_notification = DiscountEmailNotification.create!(
          notifiable: d,
          organisation: current_organisation,
          status: 'pending',
          recipient_count: DiscountEmailNotification.recipient_count_for(d, current_organisation)
        )
      end

      redirect_to bo_pricing_path(params[:org_slug], tab: 'client_tiers'),
                  notice: t('bo.pricing.client_tiers.flash.created_multiple', count: created_discounts.size)
    else
      @discount.errors.add(:base, errors.flatten.first)
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
    @customer_categories = current_organisation.customer_categories.ordered
  end

  def customer_discount_params
    params.require(:customer_discount).permit(
      :customer_id, :discount_type, :discount_value,
      :valid_from, :valid_until, :stackable, :active, :notes
    )
  end
end
