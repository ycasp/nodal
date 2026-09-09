class VariantGeneratorService
  attr_reader :product, :errors

  def initialize(product)
    @product = product
    @errors = []
  end

  def call
    return failure("Product has no attributes assigned") if product.product_attributes.empty?
    return failure("Product has no available values") if product.available_attribute_values.empty?

    generate_variants
    { success: true, variants_created: @variants_created, variants_skipped: @variants_skipped, errors: errors }
  end

  private

  def generate_variants
    @variants_created = 0
    @variants_skipped = 0

    # Group available values by attribute
    values_by_attribute = product.available_values_by_attribute

    # Generate all combinations
    combinations = generate_combinations(values_by_attribute)

    combinations.each do |combination|
      create_variant_for_combination(combination)
    end

    # Mark product as having variants generated
    product.update!(has_variants: true, variants_generated: true)
  end

  def generate_combinations(values_by_attribute)
    return [] if values_by_attribute.empty?

    # Get arrays of values for each attribute
    value_arrays = values_by_attribute.values.map(&:to_a)

    # Generate cartesian product
    return value_arrays.first.map { |v| [v] } if value_arrays.size == 1

    value_arrays.reduce(&:product).map(&:flatten)
  end

  def create_variant_for_combination(attribute_values)
    # Check if variant with same attribute values already exists
    existing_variant = find_existing_variant(attribute_values)

    if existing_variant
      @variants_skipped += 1
      return
    end

    # Build variant name from attribute values
    variant_name = build_variant_name(attribute_values)

    # Create the variant
    variant = product.product_variants.create!(
      organisation: product.organisation,
      name: variant_name,
      unit_price_cents: product.unit_price,
      unit_price_currency: product.organisation.currency,
      available: true,
      is_default: false,
      position: product.product_variants.count + 1
    )

    # Associate attribute values
    attribute_values.each do |attr_value|
      variant.variant_attribute_values.create!(product_attribute_value: attr_value)
    end

    @variants_created += 1
  rescue ActiveRecord::RecordInvalid => e
    errors << "Failed to create variant for #{attribute_values.map(&:value).join('/')}: #{e.message}"
  end

  def find_existing_variant(attribute_values)
    value_ids = attribute_values.map(&:id).sort

    product.product_variants.find do |variant|
      variant.attribute_values.pluck(:id).sort == value_ids
    end
  end

  def build_variant_name(attribute_values)
    options = attribute_values
      .sort_by { |v| v.product_attribute.position }
      .map(&:value)
      .join(' / ')

    "#{product.name} - #{options}"
  end

  def failure(message)
    errors << message
    { success: false, variants_created: 0, variants_skipped: 0, errors: errors }
  end
end
