class Bo::ProductVariantsController < Bo::BaseController
  before_action :set_product
  before_action :set_variant, only: [:edit, :update, :destroy]

  def index
    @variants = policy_scope(@product.product_variants).by_position.includes(:attribute_values)
  end

  def new
    @variant = @product.product_variants.build
    @variant.organisation = current_organisation
    load_attribute_values_for_form
    authorize @variant
  end

  def create
    @variant = @product.product_variants.build(variant_params)
    @variant.organisation = current_organisation
    authorize @variant

    if @variant.save
      assign_attribute_values
      StockRulesService.new(current_organisation).apply_to_variant(@variant)
      redirect_to bo_product_variants_path(params[:org_slug], @product), notice: t('bo.flash.variant_created')
    else
      load_attribute_values_for_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_attribute_values_for_form
  end

  def update
    @variant.photo.purge if params[:product_variant][:remove_photo] == '1'

    stock_changed = params[:product_variant].key?(:stock_quantity) &&
      params[:product_variant][:stock_quantity].to_i != @variant.stock_quantity

    if @variant.update(variant_params)
      update_attribute_values

      service = StockRulesService.new(current_organisation)
      service.apply_to_variant(@variant)
      service.recalculate_product_availability(@product)

      redirect_to bo_product_variants_path(params[:org_slug], @product), notice: t('bo.flash.variant_updated')
    else
      load_attribute_values_for_form
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @variant.order_items.any?
      redirect_to bo_product_variants_path(params[:org_slug], @product), alert: t('bo.flash.variant_has_orders')
    else
      @variant.destroy
      redirect_to bo_product_variants_path(params[:org_slug], @product), notice: t('bo.flash.variant_deleted')
    end
  end

  def generate
    authorize @product, :update?

    result = VariantGeneratorService.new(@product).call

    if result[:success]
      redirect_to bo_product_variants_path(params[:org_slug], @product),
        notice: t('bo.flash.variants_generated', created: result[:variants_created], skipped: result[:variants_skipped])
    else
      redirect_to configure_variants_bo_product_path(params[:org_slug], @product),
        alert: result[:errors].join(', ')
    end
  rescue StandardError => e
    Rails.logger.error "Variant generation failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    redirect_to configure_variants_bo_product_path(params[:org_slug], @product),
      alert: "Error generating variants: #{e.message}"
  end

  private

  def set_product
    @product = current_organisation.products.find(params[:product_id])
    authorize @product, :show?
  end

  def set_variant
    @variant = @product.product_variants.find(params[:id])
    authorize @variant
  end

  def variant_params
    params.require(:product_variant).permit(
      :name, :sku, :price, :stock_quantity, :track_stock, :published, :is_default, :photo, :stock_policy
    )
  end

  def assign_attribute_values
    ids = params.dig(:product_variant, :attribute_value_ids)&.reject(&:blank?)
    return if ids.blank?

    new_ids = ids.map(&:to_i)
    ensure_product_attribute_associations(new_ids)

    new_ids.each do |value_id|
      @variant.variant_attribute_values.create!(product_attribute_value_id: value_id)
    end
  end

  def update_attribute_values
    ids = params.dig(:product_variant, :attribute_value_ids)&.reject(&:blank?)
    new_ids = ids&.map(&:to_i) || []

    ensure_product_attribute_associations(new_ids) if new_ids.any?

    @variant.variant_attribute_values.destroy_all
    new_ids.each do |value_id|
      @variant.variant_attribute_values.create!(product_attribute_value_id: value_id)
    end

    update_variant_name
    cleanup_unused_product_attributes
  end

  def load_attribute_values_for_form
    product_attribute_ids = @product.product_attributes.pluck(:id)

    # All organisation attributes, split into product's and additional
    all_attributes = current_organisation.product_attributes.kept.by_position

    @product_values_by_attribute = {}
    @extra_values_by_attribute = {}

    all_attributes.each do |attribute|
      values = attribute.product_attribute_values.where(active: true).naturally_sorted
      if product_attribute_ids.include?(attribute.id)
        @product_values_by_attribute[attribute] = values
      else
        @extra_values_by_attribute[attribute] = values
      end
    end

    # Collect full value combinations used by other variants to prevent exact duplicates
    other_variants = @product.product_variants.where.not(id: @variant&.id).includes(:attribute_values)
    @used_combinations = other_variants.map { |v| v.attribute_values.pluck(:id).sort }
    @used_value_ids = [] # No longer restrict individual values
  end

  def ensure_product_attribute_associations(value_ids)
    values = ProductAttributeValue.where(id: value_ids).includes(:product_attribute)
    existing_attribute_ids = @product.product_product_attributes.pluck(:product_attribute_id)

    values.each do |value|
      unless existing_attribute_ids.include?(value.product_attribute_id)
        @product.product_product_attributes.create!(product_attribute_id: value.product_attribute_id)
        existing_attribute_ids << value.product_attribute_id
      end
    end

    existing_available_ids = @product.product_available_values.pluck(:product_attribute_value_id)
    missing_ids = value_ids - existing_available_ids
    missing_ids.each do |value_id|
      @product.product_available_values.create!(product_attribute_value_id: value_id)
    end
  end

  def update_variant_name
    @variant.reload
    values = @variant.attribute_values.includes(:product_attribute).sort_by { |v| v.product_attribute.position }
    if values.any?
      options = values.map(&:value).join(' / ')
      @variant.update_column(:name, "#{@product.name} - #{options}")
    end
  end

  def cleanup_unused_product_attributes
    # Find attribute IDs still in use by any variant of this product
    in_use_attribute_ids = VariantAttributeValue
      .joins(:product_attribute_value)
      .where(product_variant: @product.product_variants)
      .pluck('product_attribute_values.product_attribute_id')
      .uniq

    # Remove product_product_attributes no longer used by any variant
    unused = @product.product_product_attributes.where.not(product_attribute_id: in_use_attribute_ids)
    unused_attribute_ids = unused.pluck(:product_attribute_id)

    if unused_attribute_ids.any?
      # Remove available values for those attributes
      orphan_value_ids = ProductAttributeValue.where(product_attribute_id: unused_attribute_ids).pluck(:id)
      @product.product_available_values.where(product_attribute_value_id: orphan_value_ids).destroy_all

      # Remove the attribute association
      unused.destroy_all
    end
  end
end
