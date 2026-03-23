class Storefront::HomeController < Storefront::BaseController
  skip_after_action :verify_authorized

  def show
    @frequent_products = load_frequent_products
    @new_products = load_new_products

    unless browsing_as_member?
      @last_order = current_customer.orders.placed
                      .includes(:order_items)
                      .order(placed_at: :desc)
                      .first

      @shopping_lists = current_customer.shopping_lists
                          .ordered
                          .includes(:shopping_list_items)
                          .limit(3)

      @tier_discount = current_customer.active_customer_discount
      @special_prices_count = current_customer.customer_product_discounts.active.count
      @total_orders_count = current_customer.orders.placed.count
      @active_promo_codes = current_organisation.promo_codes.active
        .left_joins(:promo_code_customers)
        .where(eligibility: 'all_customers')
        .or(current_organisation.promo_codes.active
          .left_joins(:promo_code_customers)
          .where(eligibility: 'specific_customers', promo_code_customers: { customer_id: current_customer.id }))
        .distinct
    end

    @products_count = current_organisation.products.where(available: true).count

    # Build discount info for all displayed products
    all_products = @frequent_products + @new_products
    @product_discounts = all_products.each_with_object({}) do |product, hash|
      calculator = DiscountCalculator.new(product: product, customer: current_customer, for_display: true)
      hash[product.id] = calculator.discount_breakdown
    end
  end

  private

  def load_frequent_products
    return [] if browsing_as_member?

    # Top 8 most-ordered products by this customer
    frequent_product_ids = OrderItem
      .joins(:order)
      .where(orders: { customer_id: current_customer.id, organisation_id: current_organisation.id })
      .where.not(orders: { placed_at: nil })
      .group(:product_id)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(8)
      .pluck(:product_id)

    return [] if frequent_product_ids.empty?

    products = current_organisation.products
                 .where(id: frequent_product_ids, available: true)
                 .includes(:categories, :product_discounts)

    # Preserve frequency order
    products.sort_by { |p| frequent_product_ids.index(p.id) }
  end

  def load_new_products
    cutoff = if !browsing_as_member? && current_customer.orders.placed.exists?
               current_customer.orders.placed.order(placed_at: :desc).pick(:placed_at)
             else
               30.days.ago
             end

    base = current_organisation.products
             .where("products.created_at > ?", cutoff)
             .where(available: true)
             .includes(:categories, :product_discounts)
             .order(created_at: :desc)
             .limit(6)

    if current_organisation.hide_out_of_stock?
      keep_visible_ids = current_organisation.product_variants
                           .where(hide_when_unavailable: false)
                           .select(:product_id)
      base = base.where(available: true)
                 .or(base.where(id: keep_visible_ids))
    end

    base.to_a
  end
end
