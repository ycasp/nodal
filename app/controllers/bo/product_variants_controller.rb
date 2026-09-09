class Bo::ProductVariantsController < Bo::BaseController
  before_action :set_product
  before_action :set_variant, only: [:edit, :update, :destroy]

  def index
    @variants = policy_scope(@product.product_variants).by_position.includes(:attribute_values)
  end

  def new
    @variant = @product.product_variants.build
    @variant.organisation = current_organisation
    authorize @variant
  end

  def create
    @variant = @product.product_variants.build(variant_params)
    @variant.organisation = current_organisation
    authorize @variant

    if @variant.save
      redirect_to bo_product_variants_path(params[:org_slug], @product), notice: t('bo.flash.variant_created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @variant.update(variant_params)
      redirect_to bo_product_variants_path(params[:org_slug], @product), notice: t('bo.flash.variant_updated')
    else
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
      :name, :sku, :price, :stock_quantity, :track_stock, :available, :is_default, :photo
    )
  end
end
