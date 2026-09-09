class Storefront::ProductsController < Storefront::BaseController
  def index
    base_products = policy_scope(current_organisation.products).includes(:categories, :product_discounts)
                      .where(published: true)
    # Hide unavailable products, unless any variant has a non-hide policy
    keep_visible_ids = current_organisation.product_variants
                                           .where.not(stock_policy: ['hide', 'inherit'])
                                           .select(:product_id)
    if current_organisation.hide_out_of_stock?
      # For inherit+hide org, also keep products with inherit variants that aren't hidden
      base_products = base_products.where(available: true)
                                   .or(base_products.where(id: keep_visible_ids))
    end

    # Load categories tree for sidebar (eager load full tree to avoid N+1).
    # Unpublished categories drop out of the navigation entirely; their children
    # disappear with them, since the tree is only ever walked down from a root
    # that made it into this list.
    @all_kept_categories = current_organisation.categories.visible.by_position.to_a
    @categories = @all_kept_categories.select { |c| c.ancestry.nil? }

    # Precompute product counts and children lookup (2 queries instead of N+1).
    # Restrict to products the customer can actually see (published + visible per
    # the stock/visibility rules) so sidebar counts match the grid, not the raw
    # category links.
    direct_counts = CategoryProduct
      .where(category_id: @all_kept_categories.map(&:id))
      .where(product_id: base_products.select(:id))
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

    # Parse single selected category (accepts id or slug).
    # Deliberately still `kept` rather than `visible`: hiding a category removes
    # it from the navigation, it does not lock its products away. A direct link
    # keeps working, which is what makes it useful for previewing work in
    # progress before publishing it.
    if params[:category].present?
      cat_param = params[:category]
      @current_category = if cat_param.to_s =~ /\A\d+\z/
        current_organisation.categories.kept.find_by(id: cat_param)
      else
        current_organisation.categories.kept.find_by(slug: cat_param)
      end
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
    search_product_ids = search_products(base_products, @current_queries)

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

    # "Campanhas" view — narrow to products carrying an active campaign discount.
    if params[:promo].present?
      products = products.on_promotion
      @on_promotion = true
      # Top-level (parent) categories that contain on-promotion products, rolled
      # up from the products' own categories, shown as drill-down entries under
      # "Campanhas" (MANGO-style). Each carries the count of promo products in
      # its whole subtree.
      promo_scope = base_products.on_promotion
      promo_category_ids = CategoryProduct.where(product_id: promo_scope.select(:id)).distinct.pluck(:category_id)
      root_ids = @all_kept_categories.select { |c| promo_category_ids.include?(c.id) }
                                     .map { |c| c.path_ids.first }.uniq
      @campaign_categories = @all_kept_categories.select { |c| root_ids.include?(c.id) }
      @campaign_category_counts = @campaign_categories.to_h do |root|
        subtree_ids = @all_kept_categories.select { |c| c.id == root.id || c.path_ids.include?(root.id) }.map(&:id)
        [root.id, promo_scope.joins(:category_products).where(category_products: { category_id: subtree_ids }).distinct.count]
      end
    end

    # Parse attribute filters: params[:attrs] = { "cor" => ["vermelho", "azul"], "espessura" => ["10"] }
    @current_attrs = {}
    if params[:attrs].present? && params[:attrs].is_a?(ActionController::Parameters)
      params[:attrs].each do |attr_slug, value_slugs|
        slugs = Array(value_slugs).map(&:strip).reject(&:blank?)
        @current_attrs[attr_slug] = slugs if slugs.any?
      end
    end

    # Filter products by attribute values (AND across attributes, OR within each attribute).
    # Keep the scope *before* attributes are applied: it is the starting point for
    # recomputing each attribute's available options as an independent facet (below).
    products_before_attrs = products
    # Per-attribute matching product IDs, each relative to products_before_attrs.
    # e.g. { "cor" => [ids with red OR blue], "espessura" => [ids with 10] }
    attr_match_ids = {}
    @current_attrs.each do |attr_slug, value_slugs|
      attr_match_ids[attr_slug] = products_before_attrs
        .joins(product_variants: :variant_attribute_values)
        .joins("INNER JOIN product_attribute_values pav ON pav.id = variant_attribute_values.product_attribute_value_id")
        .joins("INNER JOIN product_attributes pa ON pa.id = pav.product_attribute_id")
        .where(product_variants: { published: true })
        .where("pa.slug = ? AND pav.slug IN (?)", attr_slug, value_slugs)
        .distinct.pluck(:id)
    end
    if attr_match_ids.any?
      # Final result = intersection across attributes (AND between attributes)
      final_ids = attr_match_ids.values.reduce(:&) || []
      products = products_before_attrs.where(id: final_ids)
    end

    # Collect available attribute filters only when a category is selected
    # (showing attributes across all categories is confusing — values from unrelated categories mix together).
    # Facets are independent: each attribute's options are computed from products filtered by
    # all OTHER selected attributes — so selecting one value never hides its siblings (OR stays usable).
    @available_attributes = @current_category ? build_available_attributes(products_before_attrs, attr_match_ids) : []

    # Sort: explicit query param wins; otherwise fall back to the current
    # category's default (if any), then the organisation's default.
    @current_sort = params[:sort].presence ||
                    @current_category&.default_product_sort.presence ||
                    current_organisation.default_product_sort
    min_variant_price = "(SELECT MIN(pv.unit_price_cents) FROM product_variants pv WHERE pv.product_id = products.id AND pv.published = true)"
    sorted_products = case @current_sort
                      when "name_desc" then products.order(name: :desc)
                      when "price_asc" then products.order(Arel.sql("#{min_variant_price} ASC NULLS LAST, products.name ASC"))
                      when "price_desc" then products.order(Arel.sql("#{min_variant_price} DESC NULLS LAST, products.name ASC"))
                      when "newest" then products.order(created_at: :desc)
                      else products.order(name: :asc)
                      end

    # Paginate results
    @pagy, @products = pagy(sorted_products)

    # Honest card pricing: the actual price (conditions respected against the
    # current cart) + a teaser for any conditional discount still to unlock.
    @cart_context = current_cart && CartDiscountContext.new(current_cart.order_items.includes(:product_variant, product: :categories).to_a)
    @product_discounts, @product_unlocks = build_card_discounts(@products)

    # Load card attributes (show_on_card) for product listing
    @card_attributes = current_organisation.product_attributes.where(show_on_card: true).by_position
    if @card_attributes.any?
      product_ids = @products.map(&:id)
      card_attr_ids = @card_attributes.map(&:id)

      # Get attribute values from published+available non-default variants (variable products)
      # AND from default variants (simple products)
      visible_value_ids = VariantAttributeValue
        .joins(product_variant: :product)
        .joins(:product_attribute_value)
        .where(products: { id: product_ids })
        .where(product_variants: { published: true, available: true })
        .where(
          "product_variants.is_default = false OR (product_variants.is_default = true AND products.has_variants = false)"
        )
        .where(product_attribute_values: { product_attribute_id: card_attr_ids })
        .pluck(:product_id, :product_attribute_value_id)

      # Group by product_id => [value_ids]
      visible_by_product = visible_value_ids.group_by(&:first).transform_values { |pairs| pairs.map(&:last).uniq }

      # Load the actual attribute values
      all_value_ids = visible_value_ids.map(&:last).uniq
      values_by_id = ProductAttributeValue.where(id: all_value_ids).includes(:product_attribute).index_by(&:id)

      @card_attribute_data = visible_by_product.transform_values do |value_ids|
        value_ids.map { |id| values_by_id[id] }.compact.group_by(&:product_attribute)
      end
    end

    @active_filters = build_active_filters
  end

  def autocomplete
    skip_authorization
    query = params[:q].to_s.strip
    if query.length < 2
      render json: []
      return
    end

    base = policy_scope(current_organisation.products).where(published: true, available: true)
    like_query = "%#{query}%"

    # Find matching categories
    categories = current_organisation.categories.kept
                   .where("unaccent(categories.name) ILIKE unaccent(?)", like_query)
                   .order(:name)
                   .limit(4)

    if categories.empty?
      categories = current_organisation.categories.kept
                     .where("word_similarity(unaccent(?), unaccent(categories.name)) > ?", query, TRIGRAM_THRESHOLD)
                     .order(:name)
                     .limit(4)
    end

    # Find matching products (by name, SKU, variant SKU, or category name)
    by_fields = base.left_joins(:product_variants)
                    .where("unaccent(products.name) ILIKE unaccent(?) OR unaccent(products.sku) ILIKE unaccent(?) OR unaccent(product_variants.sku) ILIKE unaccent(?)", like_query, like_query, like_query)
    by_cat = base.joins(:categories)
                 .where("unaccent(categories.name) ILIKE unaccent(?)", like_query)
    products = by_fields.or(base.where(id: by_cat.select(:id)))
                   .select("products.id, products.name, products.slug, products.sku")
                   .distinct
                   .order(:name)
                   .limit(5)

    if products.empty?
      products = base.where("word_similarity(unaccent(?), unaccent(products.name)) > ?", query, TRIGRAM_THRESHOLD)
                     .select(:id, :name, :slug, :sku)
                     .order(:name)
                     .limit(5)
    end

    results = {
      categories: categories.map { |c| { name: c.name, path: c.full_path, url: products_path(org_slug: params[:org_slug], category: c.slug) } },
      products: products.map { |p| { name: p.name, sku: p.sku, url: product_path(p, org_slug: params[:org_slug]) } },
      search_url: products_path(org_slug: params[:org_slug], "queries[]": query)
    }

    render json: results
  end

  def show
    @product = current_organisation.products.find(params[:id])
    authorize @product

    unless @product.published?
      redirect_to products_path(org_slug: current_organisation.slug), alert: I18n.t('storefront.products.not_available')
      return
    end

    if !@product.available?
      # Product has no available variants — check if any variant's policy would still show it
      has_visible = @product.product_variants.published.where(is_default: false).any? { |v|
        v.effective_stock_policy != 'hide'
      }
      unless has_visible
        redirect_to products_path(org_slug: current_organisation.slug), alert: I18n.t('storefront.products.not_available')
        return
      end
    end

    # Build breadcrumbs from primary category
    @primary_category = @product.primary_category
    if @primary_category
      @breadcrumbs = @primary_category.ancestors.to_a << @primary_category
    end

    # Cart aggregates up front, so per-variant prices and conditions reflect
    # what's already in the cart (honest pricing, not the best-possible price).
    @cart_context = current_cart && CartDiscountContext.new(current_cart.order_items.includes(:product_variant, product: :categories).to_a)

    # Load variants data for variable products
    if @product.has_variants?
      # Only show published, non-default variants; filter out hidden-when-unavailable
      all_variants = @product.product_variants.published.where(is_default: false)
                            .by_position.includes(:attribute_values)
      @variants = all_variants.select { |v|
        v.available? || v.effective_stock_policy != 'hide'
      }
      # Only show attribute values that lead to at least one available variant
      variant_value_ids = @variants.flat_map { |v| v.attribute_values.map(&:id) }.to_set
      @attributes_with_values = @product.available_values_by_attribute.transform_values { |values|
        values.select { |v| variant_value_ids.include?(v.id) }
      }
      @default_variant = @product.default_variant

      # Per-variant discount data for JS. Honest pricing: the price reflects the
      # discounts whose condition is actually met (against the current cart),
      # not the best-possible price. A teaser carries the conditional discount
      # that isn't met yet ("-17% a partir de €100"), so the UI can advertise it
      # without pretending it's already applied.
      min_qty = @product.quantity_input_min
      @variant_discounts = @variants.each_with_object({}) do |v, hash|
        honest = DiscountCalculator.new(product: @product, customer: current_customer,
          quantity: min_qty, for_display: false, variant: v, cart_context: @cart_context).discount_breakdown
        teaser = DiscountCalculator.new(product: @product, customer: current_customer,
          quantity: min_qty, for_display: true, variant: v, cart_context: @cart_context)
          .all_discounts.find { |d| d[:condition] && !d[:meets_condition] }
        hash[v.id] = {
          has_discount: honest[:has_discount],
          final_price_cents: honest[:final_price].cents,
          discount_percentage: honest[:has_discount] && honest[:effective_discount][:percentage].to_f.finite? ? (honest[:effective_discount][:percentage] * 100).round(0) : 0,
          teaser_percentage: teaser && teaser[:discount_type] == "percentage" ? (teaser[:value] * 100).round(0) : nil
        }
      end
    else
      @default_variant = @product.default_variant
      # Load attribute values for simple products (for display)
      if @default_variant&.attribute_values&.any?
        @simple_attribute_values = @default_variant.attribute_values
          .joins(:product_attribute)
          .includes(:product_attribute)
          .order('product_attributes.position')
      end
    end

    # for_display: true shows all available discounts (ignoring min_quantity) for display purposes.
    # For variable products, leave variant: nil so the calculator picks the cheapest published
    # variant as reference — base_price/final_price/percentage stay meaningful.
    # cart_context so the panel's met/unmet state respects what's already in the
    # cart (a summed/category threshold can be reached by other lines) — matches
    # the honest header. Without it the panel would say "Gaste €X..." even when
    # the category already cleared it (only visible on variable products, where
    # the live JS tracker isn't driving the panel until a variant is picked).
    @discount_calculator = DiscountCalculator.new(
      product: @product,
      customer: current_customer,
      for_display: true,
      variant: @product.has_variants? ? nil : @default_variant,
      cart_context: @cart_context
    )

    # Honest header price for simple products: what the customer actually pays
    # now (conditions respected against the current cart) — not the
    # best-possible price that the "available discounts" panel advertises.
    unless @product.has_variants?
      @actual_breakdown = DiscountCalculator.new(
        product: @product, customer: current_customer, quantity: 1,
        for_display: false, variant: @default_variant, cart_context: @cart_context
      ).discount_breakdown
      @product_pricing = product_pricing_data(@cart_context)
    end

    # Build the display strings used while no variant is selected. Honest: the
    # discounted range respects conditions against the cart (a conditional
    # discount not yet met does not lower the displayed price). The reference
    # breakdown (cheapest visible variant, conditions respected) drives the
    # no-selection header/badge defaults — the panel keeps its own (for_display)
    # calculator to advertise the conditions.
    if @product.has_variants?
      ref_variant = @variants.select { |v| v.unit_price_cents.to_i.positive? }.min_by(&:unit_price_cents) || @default_variant
      @reference_breakdown = DiscountCalculator.new(
        product: @product, customer: current_customer, quantity: @product.quantity_input_min,
        for_display: false, variant: ref_variant, cart_context: @cart_context
      ).discount_breakdown

      dr = @product.discounted_price_range(current_customer, for_display: false, cart_context: @cart_context)
      has_disc = dr && (dr[:final_min] < dr[:original_min] || dr[:final_max] < dr[:original_max])
      if has_disc
        @display_price_original = dr[:range] ? "#{dr[:original_min].format} - #{dr[:original_max].format}" : dr[:original_min].format
        @display_price = dr[:range] ? "#{dr[:final_min].format} - #{dr[:final_max].format}" : dr[:final_min].format
      else
        @display_price_original = nil
        @display_price = @product.display_price
      end

      # "Poupa" lives in the (optimistic) discounts panel — show the per-unit
      # savings the discount yields when applied, as a RANGE across variants
      # (a percentage discount saves more on a pricier variant).
      @display_savings = optimistic_savings_label
    else
      @display_price_original = nil
      @display_price = nil
      @display_savings = nil
    end

    # Live pricing for variable products (V2): the conditional discount lives on
    # the product, so all variants share the global tracker config; per-variant
    # locked/unlocked prices and cart contribution feed it as the variant
    # selector changes. @product_pricing carries the globals (inert until a
    # variant is chosen); @variant_pricing maps variant_id -> its values.
    if @product.has_variants?
      conditional = @discount_calculator.all_discounts.find { |d| d[:condition] }
      if conditional
        cond = conditional[:condition]
        grid = @product.grid_add_to_cart?
        # The panel tracker is shown for the selector mode, and for grid+summed
        # (grid per-line flips each row instead, so no shared tracker).
        if !grid || cond[:scope] == :summed
          @live_discount = conditional
          @product_pricing = {
            locked_unit_cents: 0, unlocked_unit_cents: 0, base_unit_cents: 0, cart_current: 0,
            currency_symbol: current_organisation.currency_symbol,
            condition_type: cond[:type].to_s,
            threshold: cond[:type] == :amount ? cond[:amount].cents : cond[:quantity],
            discount_label: discount_label_for(conditional),
            cart_current_label: t('storefront.carts.show.nudge.units', count: 0)
          }
          @variant_pricing = grid ? nil : build_variant_pricing(conditional, @cart_context)
        end
      end
    end

    # Fetch related products
    if @product.show_related_products?
      fetcher = RelatedProductsFetcher.new(product: @product, limit: 4)
      @related_products = fetcher.fetch
      @related_product_discounts, @related_product_unlocks = build_card_discounts(@related_products)
    end
  end

  private

  # Data for the live product-page pricing controller (simple products): two
  # unit prices (locked = condition unmet, unlocked = met) so JS can switch on
  # the quantity reaching the nearest conditional discount's threshold, plus
  # what's already in the cart toward a summed threshold.
  def product_pricing_data(cart_context)
    conditional = @discount_calculator.all_discounts.find { |d| d[:condition] && !d[:meets_condition] }

    data = {
      locked_unit_cents: @actual_breakdown[:final_price].cents,
      unlocked_unit_cents: @discount_calculator.final_price.cents,
      base_unit_cents: @actual_breakdown[:base_price].cents,
      currency_symbol: current_organisation.currency_symbol,
      condition_type: "none",
      threshold: 0,
      cart_current: 0,
      discount_label: ""
    }
    return data unless conditional

    cond = conditional[:condition]
    source = conditional[:source]
    @live_discount = conditional # the panel hint for this one toggles live
    data[:condition_type] = cond[:type].to_s
    data[:threshold] = cond[:type] == :amount ? cond[:amount].cents : cond[:quantity]
    data[:discount_label] = discount_label_for(conditional)
    data[:cart_current] = cart_threshold_current(cond, source, cart_context)
    # "já tem X no carrinho" reads in units of whatever scope unlocked it — the
    # whole category for a category discount, not just this product.
    data[:cart_current_label] = t('storefront.carts.show.nudge.units', count: cart_scope_quantity(cond, source, cart_context))
    data
  end

  # Units already in the cart toward the threshold, in the discount's scope:
  # the category total for a category discount, this variant's line for a
  # per-line variant, otherwise the product total. Always a count (for the
  # "já tem X no carrinho" celebration), regardless of quantity/€ condition.
  def cart_scope_quantity(cond, source, cart_context, variant: nil)
    return 0 unless cart_context

    if cond[:scope] == :summed && source.category_id.present?
      cart_context.category_quantity(source.category_id).to_i
    elsif cond[:scope] != :summed && variant
      cart_context.variant_quantity(variant.id).to_i
    else
      cart_context.product_quantity(@product.id).to_i
    end
  end

  def discount_label_for(discount)
    if discount[:discount_type] == "percentage"
      "-#{(discount[:value] * 100).round}%"
    else
      "-#{Money.new((discount[:value] * 100).to_i, current_organisation.currency).format}"
    end
  end

  # Per-unit savings the discount would yield, as a range across the variants
  # that actually get it (variants excluded from discounts are skipped, so an
  # excluded priciest variant doesn't drag the range down to €0). nil when none.
  def optimistic_savings_label
    return nil unless @variants

    min_qty = @product.quantity_input_min
    savings = @variants.filter_map do |v|
      next unless v.unit_price_cents.to_i.positive?

      bd = DiscountCalculator.new(product: @product, customer: current_customer,
        quantity: min_qty, for_display: true, variant: v, cart_context: @cart_context).discount_breakdown
      diff = bd[:base_price] - bd[:final_price]
      diff if diff.positive?
    end
    return nil if savings.empty?

    lo, hi = savings.minmax
    lo == hi ? lo.format : "#{lo.format} – #{hi.format}"
  end

  # Per-variant live-pricing values: the price with the conditional discount
  # locked (condition unmet) vs unlocked (met), the base price, and what's
  # already in the cart toward the threshold for this variant.
  def build_variant_pricing(conditional, cart_context)
    cond = conditional[:condition]
    source = conditional[:source]
    min_qty = @product.quantity_input_min
    @variants.each_with_object({}) do |v, hash|
      next unless v.unit_price_cents.to_i.positive?

      locked = DiscountCalculator.new(product: @product, customer: current_customer,
        quantity: min_qty, for_display: false, variant: v, cart_context: cart_context).final_price
      unlocked = DiscountCalculator.new(product: @product, customer: current_customer,
        quantity: min_qty, for_display: true, variant: v, cart_context: cart_context).final_price
      hash[v.id] = {
        locked_unit_cents: locked.cents,
        unlocked_unit_cents: unlocked.cents,
        base_unit_cents: v.unit_price_cents,
        cart_current: cart_threshold_current(cond, source, cart_context, variant: v),
        cart_current_label: t('storefront.carts.show.nudge.units', count: cart_scope_quantity(cond, source, cart_context, variant: v))
      }
    end
  end

  # What's already in the cart toward the threshold. For a per-line or
  # product-summed condition, adding more of this product merges into the same
  # cart line, so the product's current cart contribution counts. For a
  # category-summed condition, the whole category's cart total counts.
  def cart_threshold_current(cond, source, cart_context, variant: nil)
    return 0 unless cart_context

    if cond[:scope] == :summed && source.category_id.present?
      cond[:type] == :amount ? cart_context.category_amount_cents(source.category_id) : cart_context.category_quantity(source.category_id)
    elsif cond[:scope] != :summed && variant
      # Per-line condition on a specific variant: only that variant's own cart
      # line merges when the customer adds more.
      cond[:type] == :amount ? cart_context.variant_amount_cents(variant.id) : cart_context.variant_quantity(variant.id)
    else
      cond[:type] == :amount ? cart_context.product_amount_cents(@product.id) : cart_context.product_quantity(@product.id)
    end
  end

  TRIGRAM_THRESHOLD = 0.5

  def search_products(base_products, queries)
    return [] if queries.blank?

    product_ids = []
    queries.each do |term|
      ids = exact_search(base_products, term) + fuzzy_search(base_products, term)
      product_ids += ids
    end
    product_ids.uniq
  end

  def exact_search(base_products, term)
    query = "%#{term}%"
    ids_by_category = base_products.joins(:categories)
                                   .where("unaccent(categories.name) ILIKE unaccent(?)", query)
                                   .pluck(:id)
    ids_by_product = base_products.left_joins(:product_variants).where(
      "unaccent(products.name) ILIKE unaccent(?) OR unaccent(products.description) ILIKE unaccent(?) OR unaccent(products.sku) ILIKE unaccent(?) OR unaccent(product_variants.sku) ILIKE unaccent(?)",
      query, query, query, query
    ).pluck(:id)
    (ids_by_product + ids_by_category).uniq
  end

  def fuzzy_search(base_products, term)
    ids_by_product = base_products.where(
      "word_similarity(unaccent(?), unaccent(products.name)) > ?", term, TRIGRAM_THRESHOLD
    ).pluck(:id)
    ids_by_category = base_products.joins(:categories).where(
      "word_similarity(unaccent(?), unaccent(categories.name)) > ?", term, TRIGRAM_THRESHOLD
    ).pluck(:id)
    (ids_by_product + ids_by_category).uniq
  end

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

    @current_attrs.each do |attr_slug, value_slugs|
      attr = @available_attributes&.find { |a| a[:slug] == attr_slug }
      attr_name = attr ? attr[:name] : attr_slug

      value_slugs.each do |value_slug|
        value_label = attr&.dig(:values)&.find { |v| v[:slug] == value_slug }&.dig(:label) || value_slug
        remaining = value_slugs - [value_slug]
        remove_params = request.query_parameters.except("page").deep_dup
        if remaining.any?
          remove_params["attrs"][attr_slug] = remaining
        else
          remove_params["attrs"]&.delete(attr_slug)
          remove_params.delete("attrs") if remove_params["attrs"]&.empty?
        end

        filters << {
          type: :attribute,
          label: "#{attr_name}: #{value_label}",
          remove_params: remove_params
        }
      end
    end

    filters
  end

  def build_available_attributes(base_scope, attr_match_ids)
    base_ids = base_scope.pluck(:id)
    return [] if base_ids.empty?

    # Product IDs filtered by all selected attributes EXCEPT `except_slug`.
    # - For a selected attribute, this drops its own filter so its sibling values stay
    #   visible (OR within the attribute remains usable).
    # - For an unselected attribute, nothing is dropped, so its options reflect the
    #   current selection (AND across attributes).
    base_id_set = base_ids.to_set
    ids_excluding = lambda do |except_slug|
      attr_match_ids.each_with_object(base_id_set.dup) do |(slug, ids), acc|
        next if slug == except_slug
        acc.select! { |id| ids.include?(id) }
      end
    end
    # Memoize the allowed-id set per attribute (computed once, reused across its values).
    allowed_cache = Hash.new { |h, slug| h[slug] = ids_excluding.call(slug) }

    # One query for every (attribute, value, product) tuple in the base scope. We filter
    # per-attribute in Ruby afterwards so each facet uses its own "all others" set.
    rows = ProductAttributeValue
      .joins(:product_attribute, variant_attribute_values: { product_variant: :product })
      .where(products: { id: base_ids })
      .where(product_variants: { published: true })
      .distinct
      .order(Arel.sql("product_attributes.position"))
      .pluck(
        Arel.sql("product_attributes.id"), Arel.sql("product_attributes.name"), Arel.sql("product_attributes.slug"),
        Arel.sql("product_attributes.position"),
        Arel.sql("product_attribute_values.value"), Arel.sql("product_attribute_values.slug"),
        Arel.sql("product_attribute_values.color_hex"),
        Arel.sql("products.id")
      )

    # Group into structured data, counting distinct products per value within that
    # attribute's allowed set.
    attrs_hash = {}
    rows.each do |attr_id, attr_name, attr_slug, attr_position, val_label, val_slug, color_hex, product_id|
      next unless allowed_cache[attr_slug].include?(product_id)

      attrs_hash[attr_id] ||= { name: attr_name, slug: attr_slug, position: attr_position, values: {} }
      value = (attrs_hash[attr_id][:values][val_slug] ||= {
        label: val_label,
        slug: val_slug,
        color_hex: color_hex,
        count: 0,
        selected: @current_attrs[attr_slug]&.include?(val_slug) || false
      })
      value[:count] += 1
    end
    # Flatten value maps back into arrays (preserving the structure views expect).
    attrs_hash.each_value { |attr| attr[:values] = attr[:values].values }

    # Sort values: numeric-first (by numeric value), then alphabetical
    attrs_hash.each_value do |attr|
      attr[:values].sort_by! do |v|
        label = v[:label].to_s
        num = label[/\A[\d.]+/]
        if num
          [0, num.to_f]
        else
          [1, label.downcase]
        end
      end
    end

    attrs_hash.values.sort_by { |attr| attr[:position] || 0 }
  end

  # Per-product card data: the honest breakdown (conditions respected) and an
  # optional "unlock" teaser (nearest conditional discount not yet met).
  # Returns [discounts_by_id, unlocks_by_id].
  def build_card_discounts(products)
    @honest_cards = true # cards show the actual price + an unlock teaser, not the best-possible price
    discounts = {}
    unlocks = {}
    products.each do |product|
      # For variable products the default variant is a price-less placeholder,
      # so evaluate against the cheapest visible variant (same reference the
      # price range uses) — otherwise the breakdown degenerates and the "-X%"
      # badge goes missing.
      ref = card_reference_variant(product)
      qty = product.quantity_input_min
      discounts[product.id] = DiscountCalculator.new(
        product: product, customer: current_customer, quantity: qty, for_display: false, variant: ref, cart_context: @cart_context
      ).discount_breakdown

      unmet = DiscountCalculator.new(
        product: product, customer: current_customer, quantity: qty, for_display: true, variant: ref, cart_context: @cart_context
      ).all_discounts.find { |d| d[:condition] && !d[:meets_condition] }
      unlocks[product.id] = unmet && { discount_label: discount_label_for(unmet), condition_label: condition_label_for(unmet) }
    end
    [discounts, unlocks]
  end

  def condition_label_for(discount)
    cond = discount[:condition]
    cond[:type] == :amount ? cond[:amount].format : t('storefront.products.index.units_short', count: cond[:quantity])
  end

  # Cheapest VISIBLE variant for a variable product (same reference the price
  # range uses), or the default variant for a simple product. Visibility matters:
  # an out-of-stock (hidden) variant must not be the reference, or its
  # (missing) discount would hide a discounted in-stock variant on the card.
  def card_reference_variant(product)
    return product.default_variant unless product.has_variants?

    product.product_variants.where(is_default: false, published: true)
           .where.not(unit_price_cents: [ nil, 0 ]).to_a
           .select { |v| v.available? || v.effective_stock_policy != "hide" }
           .min_by(&:unit_price_cents) || product.default_variant
  end
end
