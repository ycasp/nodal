class Bo::ProductAttributeValuesController < Bo::BaseController
  def create
    @product_attribute = current_organisation.product_attributes.find(params[:product_attribute_id])
    authorize @product_attribute, :update?

    @value = @product_attribute.product_attribute_values.build(value: params[:value])

    if @value.save
      render json: { id: @value.id, value: @value.value, slug: @value.slug }, status: :created
    else
      render json: { errors: @value.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
