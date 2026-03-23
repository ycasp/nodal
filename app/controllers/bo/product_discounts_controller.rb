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
      update_variant_overrides
      notification = DiscountEmailNotification.create!(
        notifiable: @discount,
        organisation: current_organisation,
        status: 'pending',
        recipient_count: DiscountEmailNotification.recipient_count_for(@discount, current_organisation)
      )
      redirect_to bo_pricing_path(params[:org_slug], tab: 'product_discounts', notification_id: notification.id),
                  notice: "Product discount created successfully."
    else
      load_variants_for_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_variants_for_form
  end

  def variant_overrides
    authorize ProductDiscount.new(organisation: current_organisation), :new?
    @variants_grouped = {}

    if params[:product_id].present?
      product = current_organisation.products.find_by(id: params[:product_id])
      if product
        @variants_grouped = { product => product.product_variants.by_position.to_a }
      end
    elsif params[:category_id].present?
      category = current_organisation.categories.find_by(id: params[:category_id])
      if category
        product_ids = CategoryProduct.where(category_id: category.subtree_ids).select(:product_id)
        products = current_organisation.products
                          .where(id: product_ids)
                          .includes(:product_variants)
                          .order(:name)
        products.each do |product|
          variants = product.product_variants.by_position.to_a
          @variants_grouped[product] = variants if variants.any?
        end
      end
    end

    render partial: "variant_overrides_frame",
           locals: { variants_grouped: @variants_grouped, currency_symbol: current_organisation.currency_symbol },
           layout: false
  end

  def update
    if @discount.update(product_discount_params)
      update_variant_overrides
      redirect_to bo_pricing_path(params[:org_slug], tab: 'product_discounts'),
                  notice: "Product discount updated successfully."
    else
      load_variants_for_form
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
    @categories = current_organisation.categories.kept.arrange_serializable do |parent, children|
      { id: parent.id, name: parent.full_path, children: children }
    end
    @categories_for_select = current_organisation.categories.kept.order(:name).map do |cat|
      [cat.full_path, cat.id]
    end
  end

  def product_discount_params
    params.require(:product_discount).permit(
      :product_id, :category_id, :discount_type, :discount_value, :min_quantity,
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

    # Gather all variant IDs from the overrides, find them across org products
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
