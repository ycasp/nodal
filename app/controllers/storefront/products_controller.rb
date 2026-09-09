class Storefront::ProductsController < Storefront::BaseController
  def index
    base_products = policy_scope(current_organisation.products).includes(:categories, :product_discounts)

    # Load categories tree for sidebar
    @categories = current_organisation.categories.kept.roots.by_position

    # Parse category IDs
    if params[:categories].present?
      category_ids = Array(params[:categories]).map(&:to_i).reject(&:zero?)
      @current_categories = current_organisation.categories.kept.where(id: category_ids)
    else
      @current_categories = []
    end

    # Build product IDs from categories (OR logic)
    category_product_ids = []
    if @current_categories.any?
      all_category_ids = @current_categories.flat_map(&:subtree_ids).uniq
      category_product_ids = base_products.joins(:category_products)
                                          .where(category_products: { category_id: all_category_ids })
                                          .pluck(:id).uniq

      # Show breadcrumbs for single category selection only
      if @current_categories.size == 1
        @breadcrumbs = @current_categories.first.ancestors.to_a << @current_categories.first
      end
    end

    # Parse search queries (multiple terms with OR logic)
    @current_queries = Array(params[:queries]).map(&:strip).reject(&:blank?).uniq

    # Build product IDs from search queries (OR logic across all terms)
    search_product_ids = []
    @current_queries.each do |term|
      query = "%#{term}%"
      # Search in product name, description, and category names
      ids_by_category_name = base_products.joins(:categories)
                                          .where("categories.name ILIKE ?", query)
                                          .pluck(:id)
      ids_by_product = base_products.where(
        "products.name ILIKE ? OR products.description ILIKE ?", query, query
      ).pluck(:id)
      search_product_ids += ids_by_product + ids_by_category_name
    end
    search_product_ids = search_product_ids.uniq

    # Combine with OR logic: categories OR search
    if @current_categories.any? || @current_queries.any?
      combined_ids = (category_product_ids + search_product_ids).uniq
      @products = combined_ids.any? ? base_products.where(id: combined_ids) : base_products.none
    else
      @products = base_products
    end

    # Build discount info for all products using DiscountCalculator
    # for_display: true shows all available discounts (ignoring min_quantity) for display purposes
    @product_discounts = @products.each_with_object({}) do |product, hash|
      calculator = DiscountCalculator.new(product: product, customer: current_customer, for_display: true)
      hash[product.id] = calculator.discount_breakdown
    end

    @active_filters = build_active_filters
  end

  def show
    @product = current_organisation.products.find(params[:id])
    authorize @product

    # Build breadcrumbs from primary category
    @primary_category = @product.primary_category
    if @primary_category
      @breadcrumbs = @primary_category.ancestors.to_a << @primary_category
    end

    # Load variants data for variable products
    if @product.has_variants?
      @variants = @product.product_variants.available.by_position.includes(:attribute_values)
      @attributes_with_values = @product.available_values_by_attribute
      @default_variant = @product.default_variant
    else
      @default_variant = @product.default_variant
    end

    # for_display: true shows all available discounts (ignoring min_quantity) for display purposes
    @discount_calculator = DiscountCalculator.new(
      product: @product,
      customer: current_customer,
      for_display: true,
      variant: @default_variant
    )
  end

  private

  def build_active_filters
    filters = []

    @current_categories.each do |category|
      remaining_ids = @current_categories.map(&:id) - [ category.id ]
      remove_params = request.query_parameters.except("categories")
      remove_params["categories"] = remaining_ids if remaining_ids.any?

      filters << {
        type: :category,
        label: category.name,
        remove_params: remove_params
      }
    end

    @current_queries.each do |term|
      remaining_queries = @current_queries - [ term ]
      remove_params = request.query_parameters.except("queries")
      remove_params["queries"] = remaining_queries if remaining_queries.any?

      filters << {
        type: :query,
        label: term,
        remove_params: remove_params
      }
    end

    filters
  end
end
