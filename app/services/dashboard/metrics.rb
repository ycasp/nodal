# frozen_string_literal: true

module Dashboard
  # Service class for computing dashboard KPIs and metrics
  # All monetary values are returned as floats (e.g., 12345.67)
  # All queries are scoped to the given organisation
  class Metrics
    DEFAULT_PERIOD_DAYS = 30

    def initialize(organisation)
      @organisation = organisation
    end

    # Returns the full metrics payload as a hash
    # Accepts optional params: from, to, client_id, product_id, category_id, discount_type, include_discounts
    def to_json(params = {})
      from_date = parse_date(params[:from]) || DEFAULT_PERIOD_DAYS.days.ago.to_date
      to_date = parse_date(params[:to]) || Date.current
      prev_from = from_date - (to_date - from_date + 1).days
      prev_to = from_date - 1.day

      filters = {
        organisation: @organisation,
        from: from_date,
        to: to_date,
        client_id: params[:client_id],
        product_id: params[:product_id],
        category_id: params[:category_id],
        include_discounts: params[:include_discounts] != false
      }

      prev_filters = filters.merge(from: prev_from, to: prev_to)

      {
        meta: {
          from: from_date.iso8601,
          to: to_date.iso8601,
          org_id: @organisation.id
        },
        kpis: build_kpis(filters, prev_filters),
        top_clients: top_clients(**filters),
        order_frequency: order_frequency(**filters),
        retention_rate: { value: retention_rate(**filters) },
        orders_per_product: orders_per_product(**filters),
        revenue_per_product: revenue_per_product(**filters),
        discounts: discount_analytics(**filters.merge(discount_type: params[:discount_type]))
      }
    end

    private

    def parse_date(value)
      return nil if value.blank?
      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def build_kpis(filters, prev_filters)
      current_sales = total_sales(**filters)
      prev_sales = total_sales(**prev_filters)

      current_orders = order_count(**filters)
      prev_orders = order_count(**prev_filters)

      current_aov = aov(**filters)
      prev_aov = aov(**prev_filters)

      {
        total_sales: {
          value: current_sales,
          delta_pct: calculate_delta(current_sales, prev_sales),
          sparkline: sales_sparkline(**filters)
        },
        order_count: {
          value: current_orders,
          delta_pct: calculate_delta(current_orders, prev_orders),
          sparkline: orders_sparkline(**filters)
        },
        aov: {
          value: current_aov,
          delta_pct: calculate_delta(current_aov, prev_aov),
          sparkline: aov_sparkline(**filters)
        },
        open_carts: open_carts(**filters)
      }
    end

    def calculate_delta(current, previous)
      return 0.0 if previous.nil? || previous.zero?
      ((current - previous) / previous.to_f * 100).round(2)
    end

    # Total sales (sum of all placed order totals) in CHF/EUR
    def total_sales(organisation:, from:, to:, client_id: nil, category_id: nil, **_filters)
      orders = placed_orders_in_range(organisation, from, to)
      orders = orders.where(customer_id: client_id) if client_id.present?

      query = orders.joins(:order_items)
      query = query.joins(order_items: :product).where(products: { category_id: category_id }) if category_id.present?

      query.sum("order_items.unit_price * order_items.quantity * (1 - COALESCE(order_items.discount_percentage, 0))") / 100.0
    end

    # Count of placed orders
    def order_count(organisation:, from:, to:, client_id: nil, category_id: nil, **_filters)
      orders = placed_orders_in_range(organisation, from, to)
      orders = orders.where(customer_id: client_id) if client_id.present?
      orders = orders.joins(order_items: :product).where(products: { category_id: category_id }).distinct if category_id.present?

      orders.count
    end

    # Average order value
    def aov(organisation:, from:, to:, client_id: nil, category_id: nil, **_filters)
      orders = placed_orders_in_range(organisation, from, to)
      orders = orders.where(customer_id: client_id) if client_id.present?
      orders = orders.joins(order_items: :product).where(products: { category_id: category_id }).distinct if category_id.present?

      count = orders.count
      return 0.0 if count.zero?

      query = orders.joins(:order_items)
      query = query.joins(order_items: :product).where(products: { category_id: category_id }) if category_id.present?

      total = query.sum("order_items.unit_price * order_items.quantity * (1 - COALESCE(order_items.discount_percentage, 0))")
      (total / 100.0 / count).round(2)
    end

    # Top clients by sales
    def top_clients(organisation:, from:, to:, limit: 10, **_filters)
      prev_from = from - (to - from + 1).days
      prev_to = from - 1.day

      current_sales = customer_sales_hash(organisation, from, to)
      prev_sales = customer_sales_hash(organisation, prev_from, prev_to)

      customers = organisation.customers
        .where(id: current_sales.keys)
        .index_by(&:id)

      current_sales.sort_by { |_id, sales| -sales }
        .first(limit)
        .map do |customer_id, sales|
          customer = customers[customer_id]
          prev = prev_sales[customer_id] || 0
          {
            client_id: customer_id,
            client_name: customer&.company_name || "Unknown",
            total_sales: (sales / 100.0).round(2),
            delta_pct: calculate_delta(sales, prev)
          }
        end
    end

    # Order frequency: average orders per customer in the period
    def order_frequency(organisation:, from:, to:, **_filters)
      orders = placed_orders_in_range(organisation, from, to)
      customer_order_counts = orders.group(:customer_id).count.values

      return { value: 0.0, breakdown: { mean: 0.0, median: 0.0, distribution: [] } } if customer_order_counts.empty?

      mean = (customer_order_counts.sum.to_f / customer_order_counts.size).round(2)
      sorted = customer_order_counts.sort
      median = if sorted.size.odd?
        sorted[sorted.size / 2].to_f
      else
        ((sorted[(sorted.size / 2) - 1] + sorted[sorted.size / 2]) / 2.0).round(2)
      end

      distribution = customer_order_counts.tally.sort.map { |count, freq| { orders: count, customers: freq } }

      { value: mean, breakdown: { mean: mean, median: median, distribution: distribution } }
    end

    # Retention rate: % of customers who ordered in previous period AND current period
    def retention_rate(organisation:, from:, to:, **_filters)
      period_length = (to - from).to_i + 1
      prev_from = from - period_length.days
      prev_to = from - 1.day

      prev_customers = placed_orders_in_range(organisation, prev_from, prev_to)
        .distinct.pluck(:customer_id).to_set
      return 0.0 if prev_customers.empty?

      current_customers = placed_orders_in_range(organisation, from, to)
        .distinct.pluck(:customer_id).to_set

      retained = prev_customers & current_customers
      (retained.size.to_f / prev_customers.size).round(4)
    end

    # Open carts (draft orders)
    def open_carts(organisation:, **_filters)
      carts = organisation.orders.draft
        .includes(:customer)
        .order(updated_at: :desc)
        .limit(10)

      top_carts = carts.map do |cart|
        total = cart.order_items.sum { |item| item.unit_price * item.quantity } / 100.0
        {
          cart_id: cart.id,
          client_name: cart.customer&.company_name || "Unknown",
          cart_total: total.round(2)
        }
      end

      { value: organisation.orders.draft.count, top_carts: top_carts }
    end

    # Orders per product: count of orders containing each product
    def orders_per_product(organisation:, from:, to:, category_id: nil, limit: 20, **_filters)
      orders = placed_orders_in_range(organisation, from, to)

      query = OrderItem.where(order_id: orders.select(:id))
        .joins(:product)

      query = query.where(products: { category_id: category_id }) if category_id.present?

      product_order_counts = query.group(:product_id)
        .select("order_items.product_id, COUNT(DISTINCT order_items.order_id) as order_count")
        .order("order_count DESC")
        .limit(limit)

      product_ids = product_order_counts.map(&:product_id)
      products = Product.where(id: product_ids).index_by(&:id)

      product_order_counts.map do |row|
        product = products[row.product_id]
        {
          product_id: row.product_id,
          product_name: product&.name || "Unknown",
          order_count: row.order_count,
          sparkline: product_orders_sparkline(organisation, from, to, row.product_id)
        }
      end
    end

    # Revenue per product with discount breakdown
    def revenue_per_product(organisation:, from:, to:, category_id: nil, client_id: nil, limit: 20, **_filters)
      orders = placed_orders_in_range(organisation, from, to)
      orders = orders.where(customer_id: client_id) if client_id.present?

      query = OrderItem.where(order_id: orders.select(:id))
        .joins(:product)

      query = query.where(products: { category_id: category_id }) if category_id.present?

      revenue_data = query.group(:product_id)
        .select(
          "order_items.product_id",
          "SUM(order_items.unit_price * order_items.quantity) as gross_cents",
          "SUM(order_items.unit_price * order_items.quantity * COALESCE(order_items.discount_percentage, 0)) as discount_cents"
        )
        .order("gross_cents DESC")
        .limit(limit)

      product_ids = revenue_data.map(&:product_id)
      products = Product.where(id: product_ids).index_by(&:id)

      revenue_data.map do |row|
        product = products[row.product_id]
        gross = (row.gross_cents.to_f / 100.0).round(2)
        discount = (row.discount_cents.to_f / 100.0).round(2)
        {
          product_id: row.product_id,
          product_name: product&.name || "Unknown",
          gross_revenue: gross,
          discount_amount: discount,
          net_revenue: (gross - discount).round(2)
        }
      end
    end

    # Discount analytics
    def discount_analytics(organisation:, from:, to:, discount_type: nil, **_filters)
      orders = placed_orders_in_range(organisation, from, to)
      total_order_count = orders.count

      return empty_discount_analytics if total_order_count.zero?

      items = OrderItem.where(order_id: orders.select(:id))

      # Filter by discount type if provided
      # Note: discount_type in order_items is not stored directly, but we can filter
      # by related discount tables or by orders with specific discount characteristics
      discounted_items = items.where("COALESCE(order_items.discount_percentage, 0) > 0")

      orders_with_discount = orders.joins(:order_items)
        .where("COALESCE(order_items.discount_percentage, 0) > 0 OR orders.discount_type IS NOT NULL OR orders.auto_discount_type IS NOT NULL")
        .distinct.count

      usage_rate = (orders_with_discount.to_f / total_order_count).round(4)

      # Total discount amount (from line items + order-level discounts)
      line_item_discounts = items.sum("order_items.unit_price * order_items.quantity * COALESCE(order_items.discount_percentage, 0)") / 100.0
      order_level_discounts = calculate_order_level_discounts(orders)
      total_discounts = line_item_discounts + order_level_discounts

      avg_discount = orders_with_discount.zero? ? 0.0 : (total_discounts / orders_with_discount).round(2)

      {
        usage_rate: usage_rate,
        avg_discount_per_order: avg_discount,
        revenue_lost: total_discounts.round(2),
        top_discounted_products: top_discounted_products(organisation, from, to),
        top_clients_by_discount: top_clients_by_discount(organisation, from, to)
      }
    end

    # Sparkline data generators (daily data points)
    def sales_sparkline(organisation:, from:, to:, **_filters)
      daily_sales(organisation, from, to).map { |_, v| v }
    end

    def orders_sparkline(organisation:, from:, to:, **_filters)
      daily_orders(organisation, from, to).map { |_, v| v }
    end

    def aov_sparkline(organisation:, from:, to:, **_filters)
      sales = daily_sales(organisation, from, to)
      orders = daily_orders(organisation, from, to)

      sales.map do |date, sale_total|
        order_count = orders[date] || 0
        order_count.zero? ? 0 : (sale_total / order_count).round(2)
      end
    end

    def product_orders_sparkline(organisation, from, to, product_id)
      placed_orders_in_range(organisation, from, to)
        .joins(:order_items)
        .where(order_items: { product_id: product_id })
        .group("DATE(orders.placed_at)")
        .count
        .values
    end

    # Helper methods
    def placed_orders_in_range(organisation, from, to)
      organisation.orders.placed
        .where(placed_at: from.beginning_of_day..to.end_of_day)
    end

    def customer_sales_hash(organisation, from, to)
      placed_orders_in_range(organisation, from, to)
        .joins(:order_items)
        .group(:customer_id)
        .sum("order_items.unit_price * order_items.quantity * (1 - COALESCE(order_items.discount_percentage, 0))")
    end

    def daily_sales(organisation, from, to)
      placed_orders_in_range(organisation, from, to)
        .joins(:order_items)
        .group("DATE(orders.placed_at)")
        .sum("order_items.unit_price * order_items.quantity * (1 - COALESCE(order_items.discount_percentage, 0)) / 100.0")
        .transform_keys { |k| k.to_date }
    end

    def daily_orders(organisation, from, to)
      placed_orders_in_range(organisation, from, to)
        .group("DATE(orders.placed_at)")
        .count
        .transform_keys { |k| k.to_date }
    end

    def calculate_order_level_discounts(orders)
      # Manual order discounts
      manual_discounts = orders.where.not(discount_type: nil).sum do |order|
        if order.discount_type == 'percentage'
          order.total_amount.cents * order.discount_value / 100.0
        else
          order.discount_value || 0
        end
      end

      # Auto order tier discounts
      auto_discounts = orders.where.not(auto_discount_amount_cents: nil).sum(:auto_discount_amount_cents) / 100.0

      manual_discounts + auto_discounts
    end

    def top_discounted_products(organisation, from, to, limit: 5)
      orders = placed_orders_in_range(organisation, from, to)

      results = OrderItem.where(order_id: orders.select(:id))
        .where("COALESCE(order_items.discount_percentage, 0) > 0")
        .group(:product_id)
        .select(
          "order_items.product_id",
          "SUM(order_items.unit_price * order_items.quantity * order_items.discount_percentage) as discount_cents"
        )
        .order("discount_cents DESC")
        .limit(limit)

      product_ids = results.map(&:product_id)
      products = Product.where(id: product_ids).index_by(&:id)

      results.map do |row|
        {
          product_id: row.product_id,
          product_name: products[row.product_id]&.name || "Unknown",
          discount_amount: (row.discount_cents.to_f / 100.0).round(2)
        }
      end
    end

    def top_clients_by_discount(organisation, from, to, limit: 5)
      orders = placed_orders_in_range(organisation, from, to)

      results = orders.joins(:order_items)
        .where("COALESCE(order_items.discount_percentage, 0) > 0")
        .group("orders.customer_id")
        .select(
          "orders.customer_id as client_id",
          "SUM(order_items.unit_price * order_items.quantity * order_items.discount_percentage) as discount_cents"
        )
        .order("discount_cents DESC")
        .limit(limit)

      customer_ids = results.map(&:client_id)
      customers = Customer.where(id: customer_ids).index_by(&:id)

      results.map do |row|
        {
          client_id: row.client_id,
          client_name: customers[row.client_id]&.company_name || "Unknown",
          discount_amount: (row.discount_cents.to_f / 100.0).round(2)
        }
      end
    end

    def empty_discount_analytics
      {
        usage_rate: 0.0,
        avg_discount_per_order: 0.0,
        revenue_lost: 0.0,
        top_discounted_products: [],
        top_clients_by_discount: []
      }
    end
  end
end
