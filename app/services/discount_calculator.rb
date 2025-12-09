class DiscountCalculator
  attr_reader :product, :customer, :quantity, :for_display

  # for_display: true - shows all available discounts (ignoring min_quantity) for product pages
  # for_display: false - only shows applicable discounts (respecting min_quantity) for cart/checkout
  def initialize(product:, customer: nil, quantity: 1, for_display: false)
    @product = product
    @customer = customer
    @quantity = quantity
    @for_display = for_display
  end

  # Returns all applicable discounts with metadata
  def all_discounts
    @all_discounts ||= collect_discounts
  end

  # Returns the effective discount after applying stacking rules
  def effective_discount
    @effective_discount ||= calculate_effective_discount
  end

  # Returns the final price per unit
  def final_price
    apply_discount(product.price, effective_discount)
  end

  # Returns the total savings per unit
  def savings
    product.price - final_price
  end

  # Returns display-friendly breakdown
  def discount_breakdown
    {
      base_price: product.price,
      all_discounts: all_discounts,
      effective_discount: effective_discount,
      final_price: final_price,
      savings: savings,
      has_discount: all_discounts.any?
    }
  end

  private

  def collect_discounts
    discounts = []

    # 1. Product-level discounts (global, for all customers)
    # for_display: true - show all available discounts (ignore min_quantity)
    # for_display: false - only applicable discounts (respect min_quantity)
    product_discounts = if for_display
      product.product_discounts.active
    else
      product.product_discounts.active.where("min_quantity <= ?", quantity)
    end

    product_discounts.each do |pd|
      meets_min_quantity = quantity >= pd.min_quantity
      discounts << {
        type: :product,
        discount_type: pd.discount_type,
        value: pd.discount_value,
        stackable: pd.stackable,
        label: "Product Sale",
        valid_until: pd.valid_until,
        source: pd,
        meets_min_quantity: meets_min_quantity,
        min_quantity_required: pd.min_quantity
      }
    end

    return discounts unless customer

    # 2. Customer-product specific discounts
    cpd = product.active_discount_for(customer)
    if cpd && cpd.active?
      discounts << {
        type: :customer_product,
        discount_type: cpd.discount_type,
        value: cpd.discount_percentage,  # CustomerProductDiscount uses discount_percentage
        stackable: cpd.stackable,
        label: "Your Special Price",
        valid_until: cpd.valid_until,
        source: cpd
      }
    end

    # 3. Customer global discount (client tier)
    cd = customer.active_customer_discount
    if cd
      discounts << {
        type: :customer,
        discount_type: cd.discount_type,
        value: cd.discount_value,
        stackable: cd.stackable,
        label: "Customer Tier Discount",
        valid_until: cd.valid_until,
        source: cd
      }
    end

    discounts
  end

  def calculate_effective_discount
    return { percentage: 0, source: :none, label: nil } if all_discounts.empty?

    stackable = all_discounts.select { |d| d[:stackable] }
    exclusive = all_discounts.reject { |d| d[:stackable] }

    # Calculate stacked percentage (multiplicative for percentage, additive for fixed)
    stacked_result = calculate_stacked(stackable)

    # Find best exclusive discount
    best_exclusive = find_best_exclusive(exclusive)

    # Compare and return best option
    if stacked_result[:savings] >= best_exclusive[:savings]
      stacked_result
    else
      best_exclusive
    end
  end

  def calculate_stacked(discounts)
    return { percentage: 0, savings: Money.new(0, 'EUR'), source: :none, label: nil } if discounts.empty?

    # Start with full price
    remaining_price = product.price

    discounts.each do |d|
      if d[:discount_type] == 'percentage'
        remaining_price = remaining_price - (remaining_price * d[:value])
      else # fixed
        remaining_price = remaining_price - Money.new((d[:value] * 100).to_i, 'EUR')
      end
    end

    remaining_price = [remaining_price, Money.new(0, 'EUR')].max
    savings = product.price - remaining_price

    # Calculate effective percentage for display
    effective_pct = (savings.to_f / product.price.to_f).round(4) rescue 0

    {
      percentage: effective_pct,
      savings: savings,
      source: :stacked,
      label: "Combined Discount",
      discounts: discounts
    }
  end

  def find_best_exclusive(discounts)
    return { percentage: 0, savings: Money.new(0, 'EUR'), source: :none, label: nil } if discounts.empty?

    best = nil
    best_savings = Money.new(0, 'EUR')

    discounts.each do |d|
      savings = if d[:discount_type] == 'percentage'
        product.price * d[:value]
      else
        Money.new((d[:value] * 100).to_i, 'EUR')
      end

      if savings > best_savings
        best_savings = savings
        best = d
      end
    end

    effective_pct = (best_savings.to_f / product.price.to_f).round(4) rescue 0

    {
      percentage: effective_pct,
      savings: best_savings,
      source: best[:type],
      label: best[:label],
      discount: best
    }
  end

  def apply_discount(price, discount_info)
    return price if discount_info[:savings].nil? || discount_info[:savings].zero?

    result = price - discount_info[:savings]
    [result, Money.new(0, 'EUR')].max
  end
end
