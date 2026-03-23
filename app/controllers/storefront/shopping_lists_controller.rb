class Storefront::ShoppingListsController < Storefront::BaseController
  before_action :require_customer!
  before_action :set_shopping_list, only: [:show, :update, :destroy, :add_to_cart, :product_picker]

  def index
    @shopping_lists = policy_scope(current_customer.shopping_lists, policy_scope_class: ShoppingListPolicy::Scope)
                        .ordered
                        .includes(:shopping_list_items)
  end

  def new
    @shopping_list = current_customer.shopping_lists.build(organisation: current_organisation)
    authorize @shopping_list
  end

  def create
    @shopping_list = current_customer.shopping_lists.build(
      shopping_list_params.merge(organisation: current_organisation)
    )
    authorize @shopping_list

    if @shopping_list.save
      redirect_to shopping_list_path(org_slug: params[:org_slug], id: @shopping_list),
                  notice: t('storefront.shopping_lists.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @items = @shopping_list.shopping_list_items
               .includes(product: [:categories], product_variant: [])
               .order(created_at: :desc)
  end

  def update
    if @shopping_list.update(shopping_list_params)
      respond_to do |format|
        format.html { redirect_to shopping_list_path(org_slug: params[:org_slug], id: @shopping_list), notice: t('storefront.shopping_lists.flash.updated') }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("shopping_list_name", partial: "storefront/shopping_lists/list_name", locals: { shopping_list: @shopping_list }) }
      end
    end
  end

  def destroy
    @shopping_list.destroy
    redirect_to shopping_lists_path(org_slug: params[:org_slug]),
                notice: t('storefront.shopping_lists.flash.deleted')
  end

  def add_to_cart
    cart = current_cart
    skipped_items = []

    @shopping_list.shopping_list_items.includes(:product, :product_variant).each do |item|
      product = item.product

      if product.nil? || !product.available?
        skipped_items << item.product&.name || "Unknown product"
        next
      end

      variant = item.product_variant
      if variant.present? && !variant.purchasable?
        skipped_items << "#{product.name} (#{variant.option_values_string})"
        next
      end

      existing = cart.order_items.find_by(product: product, product_variant: variant)
      if existing
        existing.update!(quantity: existing.quantity + item.quantity)
      else
        cart.order_items.create!(
          product: product,
          product_variant: variant,
          quantity: item.quantity
        )
      end
    end

    if skipped_items.any?
      flash[:warning] = t('storefront.shopping_lists.flash.add_to_cart_skipped', items: skipped_items.join(', '))
    else
      flash[:notice] = t('storefront.shopping_lists.flash.add_to_cart_success', name: @shopping_list.name)
    end

    redirect_to cart_path(org_slug: params[:org_slug])
  end

  def product_picker
    base_products = current_organisation.products.where(available: true)
                      .includes(:categories, :product_variants)

    if current_organisation.hide_out_of_stock?
      keep_visible_ids = current_organisation.product_variants
                                             .where(hide_when_unavailable: false)
                                             .select(:product_id)
      base_products = base_products.where(available: true)
                                   .or(base_products.where(id: keep_visible_ids))
    end

    if params[:search].present?
      query = "%#{params[:search]}%"
      base_products = base_products.where(
        "unaccent(products.name) ILIKE unaccent(?) OR unaccent(products.sku) ILIKE unaccent(?)", query, query
      )
    end

    if params[:category_id].present?
      category = current_organisation.categories.kept.find_by(id: params[:category_id])
      if category
        all_category_ids = category.subtree_ids
        product_ids = base_products.joins(:category_products)
                                   .where(category_products: { category_id: all_category_ids })
                                   .pluck(:id).uniq
        base_products = base_products.where(id: product_ids)
      end
    end

    @categories = current_organisation.categories.kept.roots.by_position
    @pagy, @products = pagy(base_products.order(:name), items: 10)

    render partial: "product_picker", locals: { shopping_list: @shopping_list, products: @products, categories: @categories, pagy: @pagy }
  end

  private

  def set_shopping_list
    @shopping_list = current_customer.shopping_lists.find(params[:id])
    authorize @shopping_list
  end

  def shopping_list_params
    params.require(:shopping_list).permit(:name, :notes)
  end
end
