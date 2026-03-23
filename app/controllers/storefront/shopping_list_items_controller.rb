class Storefront::ShoppingListItemsController < Storefront::BaseController
  before_action :require_customer!
  before_action :set_shopping_list

  def create
    @product = current_organisation.products.find(params[:product_id])

    @variant = if params[:variant_id].present?
      @product.product_variants.find(params[:variant_id])
    else
      @product.default_variant
    end

    @item = @shopping_list.shopping_list_items.find_by(product: @product, product_variant: @variant)

    if @item
      @item.quantity += (params.dig(:shopping_list_item, :quantity) || 1).to_i
    else
      @item = @shopping_list.shopping_list_items.build(
        product: @product,
        product_variant: @variant,
        quantity: (params.dig(:shopping_list_item, :quantity) || 1).to_i
      )
    end

    authorize @item

    if @item.save
      respond_to do |format|
        format.html {
          redirect_back fallback_location: shopping_list_path(org_slug: params[:org_slug], id: @shopping_list),
                        notice: t('storefront.shopping_lists.flash.item_added_to_list', product: @product.name, list: @shopping_list.name)
        }
        format.turbo_stream {
          @items = @shopping_list.shopping_list_items
                     .includes(product: [:categories], product_variant: [])
                     .order(created_at: :desc)
        }
      end
    else
      redirect_back fallback_location: shopping_list_path(org_slug: params[:org_slug], id: @shopping_list),
                    alert: @item.errors.full_messages.join(", ")
    end
  end

  def update
    @item = @shopping_list.shopping_list_items.find(params[:id])
    authorize @item

    if @item.update(item_params)
      respond_to do |format|
        format.html { redirect_to shopping_list_path(org_slug: params[:org_slug], id: @shopping_list), notice: t('storefront.shopping_lists.flash.item_updated') }
        format.turbo_stream
      end
    else
      redirect_to shopping_list_path(org_slug: params[:org_slug], id: @shopping_list),
                  alert: @item.errors.full_messages.join(", ")
    end
  end

  def destroy
    @item = @shopping_list.shopping_list_items.find(params[:id])
    authorize @item
    @item.destroy

    respond_to do |format|
      format.html { redirect_to shopping_list_path(org_slug: params[:org_slug], id: @shopping_list), notice: t('storefront.shopping_lists.flash.item_removed') }
      format.turbo_stream
    end
  end

  private

  def set_shopping_list
    @shopping_list = current_customer.shopping_lists.find(params[:shopping_list_id])
  end

  def item_params
    params.require(:shopping_list_item).permit(:quantity)
  end
end
