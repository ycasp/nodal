class RelatedProductsFetcher
  DEFAULT_LIMIT = 4

  def initialize(product:, limit: DEFAULT_LIMIT)
    @product = product
    @organisation = product.organisation
    @limit = limit
  end

  def fetch
    return [] unless feature_enabled?

    combined_products = manual_related_products

    if combined_products.size < @limit
      remaining_slots = @limit - combined_products.size
      auto_filled = auto_fill_products(combined_products.pluck(:id), remaining_slots)
      combined_products += auto_filled
    end

    combined_products.take(@limit)
  end

  private

  def feature_enabled?
    @product.show_related_products?
  end

  def manual_related_products
    related_ids = @product.related_product_associations
                          .order(:position)
                          .pluck(:related_product_id)

    return [] if related_ids.empty?

    products = visible_scope.where(id: related_ids).index_by(&:id)
    related_ids.map { |id| products[id] }.compact.take(@limit)
  end

  def auto_fill_products(exclude_ids, limit)
    exclude_ids = exclude_ids + [@product.id]

    same_category_products
      .merge(visible_scope)
      .where.not(id: exclude_ids)
      .order(created_at: :desc)
      .limit(limit)
      .to_a
  end

  def same_category_products
    category_ids = @product.categories.pluck(:id)
    category_ids << @product.category_id if @product.category_id.present?

    return Product.none if category_ids.empty?

    product_ids_from_categories = CategoryProduct.where(category_id: category_ids).pluck(:product_id)
    product_ids_from_legacy = Product.where(category_id: category_ids, organisation_id: @organisation.id).pluck(:id)

    all_product_ids = (product_ids_from_categories + product_ids_from_legacy).uniq

    Product.where(id: all_product_ids, organisation_id: @organisation.id)
  end

  # Apply the same visibility rules as the storefront product listing
  def visible_scope
    scope = @organisation.products.where(published: true)

    if @organisation.hide_out_of_stock?
      keep_visible_ids = @organisation.product_variants
                                      .where.not(stock_policy: ['hide', 'inherit'])
                                      .select(:product_id)
      scope = scope.where(available: true).or(scope.where(id: keep_visible_ids))
    end

    scope
  end
end
