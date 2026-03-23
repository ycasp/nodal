class Bo::CustomerProductDiscountsController < Bo::BaseController
  before_action :set_discount, only: [:edit, :update, :destroy, :toggle_active]
  before_action :load_form_collections, only: [:new, :create, :edit, :update]

  def index
    @discounts = policy_scope(current_organisation.customer_product_discounts).includes(:customer, :product)
  end

  def new
    @discount = CustomerProductDiscount.new
    authorize @discount
  end

  def create
    customer_ids = Array(params[:customer_ids]).reject(&:blank?)
    customer_category_ids = Array(params[:customer_category_ids]).reject(&:blank?)

    if customer_ids.empty? && customer_category_ids.empty?
      @discount = CustomerProductDiscount.new(customer_product_discount_params.except(:customer_id, :customer_category_id))
      @discount.organisation = current_organisation
      @discount.customer_id = nil
      authorize @discount
      @discount.errors.add(:base, t('bo.pricing.custom_pricing.select_at_least_one'))
      load_variants_for_form
      return render :new, status: :unprocessable_entity
    end

    @discount = CustomerProductDiscount.new(customer_product_discount_params.except(:customer_id, :customer_category_id))
    @discount.organisation = current_organisation
    @discount.customer_id = customer_ids.first if customer_ids.any?
    @discount.customer_category_id = customer_category_ids.first if customer_ids.empty? && customer_category_ids.any?
    authorize @discount

    created_discounts = []
    errors = []

    customer_ids.each do |cid|
      discount = CustomerProductDiscount.new(customer_product_discount_params.except(:customer_id, :customer_category_id))
      discount.organisation = current_organisation
      discount.customer_id = cid
      if discount.save
        created_discounts << discount
      else
        errors << discount.errors.full_messages
      end
    end

    customer_category_ids.each do |ccid|
      discount = CustomerProductDiscount.new(customer_product_discount_params.except(:customer_id, :customer_category_id))
      discount.organisation = current_organisation
      discount.customer_category_id = ccid
      if discount.save
        created_discounts << discount
      else
        errors << discount.errors.full_messages
      end
    end

    if created_discounts.any?
      update_variant_overrides

      created_discounts.each do |d|
        DiscountEmailNotification.create!(
          notifiable: d,
          organisation: current_organisation,
          status: 'pending',
          recipient_count: DiscountEmailNotification.recipient_count_for(d, current_organisation)
        )
      end

      redirect_to bo_pricing_path(params[:org_slug], tab: 'custom_pricing'),
                  notice: t('bo.pricing.custom_pricing.flash.created_multiple', count: created_discounts.size)
    else
      @discount.errors.add(:base, errors.flatten.first)
      load_variants_for_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_variants_for_form
  end

  def variant_overrides
    authorize CustomerProductDiscount.new(organisation: current_organisation), :new?
    @variants_grouped = {}

    if params[:product_id].present?
      product = current_organisation.products.find_by(id: params[:product_id])
      @variants_grouped = { product => product.product_variants.by_position.to_a } if product
    elsif params[:category_id].present?
      category = current_organisation.categories.find_by(id: params[:category_id])
      if category
        product_ids = CategoryProduct.where(category_id: category.subtree_ids).select(:product_id)
        current_organisation.products.where(id: product_ids).includes(:product_variants).order(:name).each do |product|
          variants = product.product_variants.by_position.to_a
          @variants_grouped[product] = variants if variants.any?
        end
      end
    end

    render partial: "bo/product_discounts/variant_overrides_frame", locals: { variants_grouped: @variants_grouped, currency_symbol: current_organisation.currency_symbol }, layout: false
  end

  def update
    if @discount.update(customer_product_discount_params)
      update_variant_overrides
      redirect_to bo_pricing_path(params[:org_slug], tab: 'custom_pricing'),
                  notice: "Custom price updated successfully."
    else
      load_variants_for_form
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @discount.destroy
    redirect_to bo_pricing_path(params[:org_slug], tab: 'custom_pricing'),
                notice: "Custom price deleted successfully."
  end

  def toggle_active
    @discount.update(active: !@discount.active)
    redirect_to bo_pricing_path(params[:org_slug], tab: 'custom_pricing'),
                notice: "Discount #{@discount.active? ? 'activated' : 'deactivated'}."
  end

  private

  def set_discount
    @discount = current_organisation.customer_product_discounts.find(params[:id])
    authorize @discount
  end

  def load_form_collections
    @customers = current_organisation.customers.order(:company_name)
    @customer_categories = current_organisation.customer_categories.ordered
    @products = current_organisation.products.order(:name)
    @categories_for_select = current_organisation.categories.kept.order(:name).map do |cat|
      [cat.full_path, cat.id]
    end
  end

  def customer_product_discount_params
    params.require(:customer_product_discount).permit(
      :customer_id, :product_id, :category_id, :discount_percentage, :discount_type,
      :valid_from, :valid_until, :stackable, :active
    )
  end

  def load_variants_for_form
    if @discount.product?
      @variants_grouped = { @discount.product => @discount.product.product_variants.by_position.to_a }
    elsif @discount.category?
      @variants_grouped = {}
      product_ids = CategoryProduct.where(category_id: @discount.category.subtree_ids).select(:product_id)
      current_organisation.products.where(id: product_ids).includes(:product_variants).order(:name).each do |product|
        variants = product.product_variants.by_position.to_a
        @variants_grouped[product] = variants if variants.any?
      end
    else
      @variants_grouped = {}
    end
  end

  def update_variant_overrides
    overrides = params[:variant_overrides]
    return unless overrides

    variant_ids = overrides.keys.map(&:to_i)
    variants = ProductVariant.joins(:product)
                             .where(products: { organisation_id: current_organisation.id })
                             .where(id: variant_ids)

    variants.each do |variant|
      data = overrides[variant.id.to_s]
      variant.update(
        exclude_from_discounts: data[:exclude_from_discounts] == "1",
        custom_discount_type: data[:custom_discount_type].presence,
        custom_discount_value: data[:custom_discount_value].presence
      )
    end
  end
end
