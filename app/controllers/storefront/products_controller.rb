class Storefront::ProductsController < Storefront::BaseController
  def index
    base_products = policy_scope(current_organisation.products).includes(:categories, :product_discounts)
    if current_organisation.hide_out_of_stock?
      # Hide unavailable products, unless any variant opts out of hiding
      keep_visible_ids = current_organisation.product_variants
                                             .where(hide_when_unavailable: false)
                                             .select(:product_id)
      base_products = base_products.where(available: true)
                                   .or(base_products.where(id: keep_visible_ids))
    end

    # Load categories tree for sidebar (eager load full tree to avoid N+1)
    @all_kept_categories = current_organisation.categories.kept.by_position.to_a
    @categories = @all_kept_categories.select { |c| c.ancestry.nil? }

    # Precompute product counts and children lookup (2 queries instead of N+1)
    direct_counts = CategoryProduct
      .where(category_id: @all_kept_categories.map(&:id))
      .group(:category_id)
      .distinct
      .count(:product_id)
    # Sum descendant counts in memory using ancestry strings
    @category_counts = {}
    @all_kept_categories.each do |cat|
      descendant_ids = @all_kept_categories
        .select { |c| c.id == cat.id || c.ancestry.to_s.split('/').map(&:to_i).include?(cat.id) }
        .map(&:id)
      @category_counts[cat.id] = direct_counts.values_at(*descendant_ids).compact.sum
    end
    # Children lookup to avoid N+1 in tree rendering
    @category_children = @all_kept_categories.group_by(&:parent_id)

    # Parse single selected category
    if params[:category].present?
      @current_category = current_organisation.categories.kept.find_by(id: params[:category].to_i)
    end
    # Keep as array for backward compatibility with shared views
    @current_categories = @current_category ? [ @current_category ] : []

    # Build product IDs from selected category (includes subcategories)
    category_product_ids = []
    if @current_category
      all_category_ids = @current_category.subtree_ids
      category_product_ids = base_products.joins(:category_products)
                                          .where(category_products: { category_id: all_category_ids })
                                          .pluck(:id).uniq

      @breadcrumbs = @current_category.ancestors.to_a << @current_category
    end

    # Parse search queries (multiple terms with OR logic)
    @current_queries = Array(params[:queries]).map(&:strip).reject(&:blank?).uniq

    # Build product IDs from search queries (OR logic across all terms)
    search_product_ids = []
    @current_queries.each do |term|
      query = "%#{term}%"
      # Search in product name, description, and category names
      ids_by_category_name = base_products.joins(:categories)
                                          .where("unaccent(categories.name) ILIKE unaccent(?)", query)
                                          .pluck(:id)
      ids_by_product = base_products.left_joins(:product_variants).where(
        "unaccent(products.name) ILIKE unaccent(?) OR unaccent(products.description) ILIKE unaccent(?) OR unaccent(products.sku) ILIKE unaccent(?) OR unaccent(product_variants.sku) ILIKE unaccent(?)", query, query, query, query
      ).pluck(:id)
      search_product_ids += ids_by_product + ids_by_category_name
    end
    search_product_ids = search_product_ids.uniq

    # Combine with AND logic: category AND search (intersection)
    if @current_category && @current_queries.any?
      combined_ids = (category_product_ids & search_product_ids)
      products = combined_ids.any? ? base_products.where(id: combined_ids) : base_products.none
    elsif @current_category
      products = category_product_ids.any? ? base_products.where(id: category_product_ids) : base_products.none
    elsif @current_queries.any?
      products = search_product_ids.any? ? base_products.where(id: search_product_ids) : base_products.none
    else
      products = base_products
    end

    # Sort
    @current_sort = params[:sort].presence || "name_asc"
    min_variant_price = "(SELECT MIN(pv.unit_price_cents) FROM product_variants pv WHERE pv.product_id = products.id AND pv.available = true)"
    sorted_products = case @current_sort
                      when "name_desc" then products.order(name: :desc)
                      when "price_asc" then products.order(Arel.sql("#{min_variant_price} ASC NULLS LAST, products.name ASC"))
                      when "price_desc" then products.order(Arel.sql("#{min_variant_price} DESC NULLS LAST, products.name ASC"))
                      when "newest" then products.order(created_at: :desc)
                      else products.order(name: :asc)
                      end

    # Paginate results
    @pagy, @products = pagy(sorted_products)

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

    if current_organisation.hide_out_of_stock? && !@product.available?
      unless @product.product_variants.exists?(hide_when_unavailable: false)
        redirect_to storefront_products_path, alert: I18n.t('storefront.products.not_available')
        return
      end
    end

    # Build breadcrumbs from primary category
    @primary_category = @product.primary_category
    if @primary_category
      @breadcrumbs = @primary_category.ancestors.to_a << @primary_category
    end

    # Load variants data for variable products
    if @product.has_variants?
      # Include unavailable variants that opted out of hiding (show with "Sem Stock" badge)
      if current_organisation.hide_out_of_stock?
        @variants = @product.product_variants
                            .where(available: true)
                            .or(@product.product_variants.where(available: false, hide_when_unavailable: false))
                            .by_position.includes(:attribute_values)
      else
        @variants = @product.product_variants.available.by_position.includes(:attribute_values)
      end
      @attributes_with_values = @product.available_values_by_attribute
      @default_variant = @product.default_variant

      # Compute per-variant discount data for JS
      @variant_discounts = @variants.each_with_object({}) do |v, hash|
        calc = DiscountCalculator.new(product: @product, customer: current_customer, for_display: true, variant: v)
        bd = calc.discount_breakdown
        hash[v.id] = {
          has_discount: bd[:has_discount],
          final_price_cents: bd[:final_price].cents,
          discount_percentage: bd[:has_discount] ? (bd[:effective_discount][:percentage] * 100).round(0) : 0
        }
      end
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

    # Fetch related products
    if @product.show_related_products?
      fetcher = RelatedProductsFetcher.new(product: @product, limit: 4)
      @related_products = fetcher.fetch
      @related_product_discounts = build_discounts_for(@related_products)
    end
  end

  private

  def build_active_filters
    filters = []

    @current_queries.each do |term|
      remaining_queries = @current_queries - [ term ]
      remove_params = request.query_parameters.except("queries", "page")
      remove_params["queries"] = remaining_queries if remaining_queries.any?

      filters << {
        type: :query,
        label: term,
        remove_params: remove_params
      }
    end

    filters
  end

  def build_discounts_for(products)
    products.each_with_object({}) do |product, hash|
      calculator = DiscountCalculator.new(product: product, customer: current_customer, for_display: true)
      hash[product.id] = calculator.discount_breakdown
    end
  end
end
