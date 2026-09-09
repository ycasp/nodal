class Bo::ProductAttributesController < Bo::BaseController
  before_action :set_product_attribute, only: [:show, :edit, :update, :destroy, :restore]

  def index
    @product_attributes = policy_scope(current_organisation.product_attributes.kept.by_position)
  end

  def show
  end

  def new
    @product_attribute = ProductAttribute.new
    @product_attribute.product_attribute_values.build
    authorize @product_attribute
  end

  def create
    @product_attribute = ProductAttribute.new(product_attribute_params)
    @product_attribute.organisation = current_organisation
    authorize @product_attribute

    if @product_attribute.save
      redirect_to bo_product_attributes_path(params[:org_slug]), notice: t('bo.flash.product_attribute_created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product_attribute.update(product_attribute_params)
      redirect_to bo_product_attributes_path(params[:org_slug]), notice: t('bo.flash.product_attribute_updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @product_attribute.products.any?
      redirect_to bo_product_attributes_path(params[:org_slug]), alert: t('bo.flash.product_attribute_in_use')
    else
      @product_attribute.discard
      redirect_to bo_product_attributes_path(params[:org_slug]), notice: t('bo.flash.product_attribute_deleted')
    end
  end

  def restore
    @product_attribute.undiscard
    redirect_to bo_product_attributes_path(params[:org_slug]), notice: t('bo.flash.product_attribute_restored')
  end

  def reorder
    attribute_ids = params[:attribute_ids] || []

    attribute_ids.each_with_index do |id, index|
      current_organisation.product_attributes.find(id).update(position: index + 1)
    end

    head :ok
  end

  private

  def set_product_attribute
    @product_attribute = current_organisation.product_attributes.find(params[:id])
    authorize @product_attribute
  end

  def product_attribute_params
    params.require(:product_attribute).permit(
      :name, :slug, :active,
      product_attribute_values_attributes: [:id, :value, :slug, :color_hex, :position, :active, :_destroy]
    )
  end
end
