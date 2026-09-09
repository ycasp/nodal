require "csv"

class ProductImportService
  Result = Struct.new(:created, :updated, :errors, :total, keyword_init: true)

  IMPORTABLE_FIELDS = {
    "name" => { required: true, type: :string },
    "description" => { required: false, type: :string },
    "sku" => { required: false, type: :string },
    "price" => { required: false, type: :money },
    "unit_description" => { required: false, type: :string },
    "min_quantity" => { required: false, type: :integer },
    "min_quantity_type" => { required: false, type: :string },
    "available" => { required: false, type: :boolean }
  }.freeze

  def initialize(organisation:, csv_content:, column_mapping:, col_sep: ",")
    @organisation = organisation
    @csv_content = csv_content
    @column_mapping = column_mapping # { "CSV Column Name" => "product_field" }
    @col_sep = col_sep
  end

  def call
    results = { created: 0, updated: 0, errors: [] }

    CSV.parse(@csv_content, headers: true, col_sep: @col_sep).each.with_index(2) do |row, line_num|
      process_row(row, line_num, results)
    end

    Result.new(**results, total: results[:created] + results[:updated])
  end

  def self.importable_fields
    IMPORTABLE_FIELDS.keys
  end

  private

  def process_row(row, line_num, results)
    attributes = extract_attributes(row)

    # Skip empty rows
    return if attributes.values.all?(&:blank?)

    # Validate required fields
    validation_errors = validate_attributes(attributes, line_num)
    if validation_errors.any?
      results[:errors].concat(validation_errors)
      return
    end

    # Find or initialize product
    product = find_or_initialize_product(attributes)

    # Assign attributes
    assign_attributes(product, attributes)

    if product.save
      if product.previously_new_record?
        results[:created] += 1
      else
        results[:updated] += 1
      end
    else
      product.errors.full_messages.each do |message|
        results[:errors] << { row: line_num, field: nil, message: message }
      end
    end
  rescue StandardError => e
    results[:errors] << { row: line_num, field: nil, message: e.message }
  end

  def extract_attributes(row)
    attributes = {}

    @column_mapping.each do |csv_column, product_field|
      next if product_field.blank?
      next unless IMPORTABLE_FIELDS.key?(product_field)

      raw_value = row[csv_column]
      attributes[product_field] = convert_value(raw_value, IMPORTABLE_FIELDS[product_field][:type])
    end

    attributes
  end

  def convert_value(value, type)
    return nil if value.blank?

    case type
    when :string
      value.to_s.strip
    when :integer
      value.to_i
    when :money
      parse_money(value)
    when :boolean
      parse_boolean(value)
    else
      value
    end
  end

  def parse_money(value)
    return nil if value.blank?

    # Handle various decimal separators
    cleaned = value.to_s.gsub(/[^\d.,\-]/, "")

    # If both . and , exist, determine which is the decimal separator
    if cleaned.include?(".") && cleaned.include?(",")
      # If comma comes after period, comma is decimal separator (European format)
      if cleaned.rindex(",") > cleaned.rindex(".")
        cleaned = cleaned.gsub(".", "").gsub(",", ".")
      else
        # Period is decimal separator (US format)
        cleaned = cleaned.gsub(",", "")
      end
    elsif cleaned.include?(",")
      # Single comma - assume decimal separator
      cleaned = cleaned.gsub(",", ".")
    end

    (cleaned.to_f * 100).round
  end

  def parse_boolean(value)
    return true if value.blank? # Default to available
    return true if value.to_s.downcase.in?(%w[true yes 1 y t sim oui si])
    return false if value.to_s.downcase.in?(%w[false no 0 n f nao non])
    true # Default
  end

  def validate_attributes(attributes, line_num)
    errors = []

    IMPORTABLE_FIELDS.each do |field, config|
      if config[:required] && attributes[field].blank?
        errors << { row: line_num, field: field, message: "#{field.humanize} is required" }
      end
    end

    errors
  end

  def find_or_initialize_product(attributes)
    sku = attributes["sku"]

    if sku.present?
      @organisation.products.find_or_initialize_by(sku: sku)
    else
      @organisation.products.new
    end
  end

  def assign_attributes(product, attributes)
    attributes.each do |field, value|
      next if value.nil?

      case field
      when "price"
        product.unit_price = value
      when "available"
        product.available = value if product.respond_to?(:available=)
      else
        product.send("#{field}=", value) if product.respond_to?("#{field}=")
      end
    end

    product.organisation = @organisation unless product.persisted?
  end
end
