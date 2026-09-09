require "csv"

class ProductImportService
  Result = Struct.new(:created, :updated, :photos_attached, :errors, :total, keyword_init: true)

  IMPORTABLE_FIELDS = {
    "name" => { required: true, type: :string },
    "description" => { required: false, type: :string },
    "sku" => { required: false, type: :string },
    "price" => { required: false, type: :money },
    "category" => { required: false, type: :string },
    "unit_description" => { required: false, type: :string },
    "min_quantity" => { required: false, type: :integer },
    "min_quantity_type" => { required: false, type: :string },
    "available" => { required: false, type: :boolean }
  }.freeze

  def initialize(organisation:, csv_content:, column_mapping:, col_sep: ",", zip_path: nil, images_dir: nil, photo_mode: "append", form_category_id: nil, on_progress: nil)
    @organisation = organisation
    @csv_content = csv_content
    @column_mapping = column_mapping
    @col_sep = col_sep
    @zip_path = zip_path
    @images_dir = images_dir
    @photo_mode = photo_mode # "append" or "replace"
    @form_category_id = form_category_id
    @images_by_sku = {}
    @imported_products = []
    # Called once per row. The job uses it to report progress and to stop
    # early when the task was cancelled, so it may raise — deliberately, and
    # between rows, where a half-finished import is at least a coherent one.
    @on_progress = on_progress
  end

  def call
    results = { created: 0, updated: 0, photos_attached: 0, errors: [] }

    extract_images_from_zip if @zip_path.present?
    load_images_from_dir if @images_dir.present?

    rows = CSV.parse(@csv_content, headers: true, col_sep: @col_sep)
    rows.each.with_index(2) do |row, line_num|
      process_row(row, line_num, results)
      @on_progress&.call(line_num - 1, rows.size)
    end

    # Also match photos to variants by SKU
    attach_variant_photos(results) if @images_by_sku.present?

    recalculate_availability

    Result.new(**results, total: results[:created] + results[:updated])
  ensure
    cleanup_extracted_images
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

    # Assign category
    assign_category(product, attributes)

    if product.save
      @imported_products << product

      if product.previously_new_record?
        results[:created] += 1
      else
        results[:updated] += 1
      end

      # Attach photos after save (need persisted product)
      results[:photos_attached] += attach_photos(product)
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

    cleaned = value.to_s.gsub(/[^\d.,\-]/, "")

    if cleaned.include?(".") && cleaned.include?(",")
      if cleaned.rindex(",") > cleaned.rindex(".")
        cleaned = cleaned.gsub(".", "").gsub(",", ".")
      else
        cleaned = cleaned.gsub(",", "")
      end
    elsif cleaned.include?(",")
      cleaned = cleaned.gsub(",", ".")
    end

    (cleaned.to_f * 100).round
  end

  def parse_boolean(value)
    return true if value.blank?
    return true if value.to_s.downcase.in?(%w[true yes 1 y t sim oui si])
    return false if value.to_s.downcase.in?(%w[false no 0 n f nao non])
    true
  end

  def validate_attributes(attributes, line_num)
    errors = []

    IMPORTABLE_FIELDS.each do |field, config|
      next if field == "category"
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
      next if field == "category"

      case field
      when "price"
        product.unit_price = value
      when "available"
        product.published = value if product.respond_to?(:published=)
      else
        product.send("#{field}=", value) if product.respond_to?("#{field}=")
      end
    end

    product.organisation = @organisation unless product.persisted?
  end

  def assign_category(product, attributes)
    csv_category_name = attributes["category"]

    # Priority 1: Category name from CSV row (must match existing)
    if csv_category_name.present?
      category = @organisation.categories.kept.find_by("unaccent(name) ILIKE unaccent(?)", csv_category_name)
    end

    # Priority 2: Category selected in the form
    if category.nil? && @form_category_id.present?
      category = @organisation.categories.kept.find_by(id: @form_category_id)
    end

    # Priority 3: Fallback — auto-created timestamp category
    if category.nil?
      category = find_or_create_fallback_category
    end

    # Add category to product if not already assigned
    if category && !product.categories.include?(category)
      product.categories << category
    end
  end

  def find_or_create_fallback_category
    @fallback_category ||= begin
      name = "Importação #{Time.current.strftime('%d-%m-%Y %H:%M')}"
      @organisation.categories.create!(name: name)
    end
  end

  # --- Image handling ---

  def extract_images_from_zip
    return unless @zip_path.present? && File.exist?(@zip_path)

    @extracted_dir = Rails.root.join("tmp", "imports", "images_#{SecureRandom.uuid}").to_s
    FileUtils.mkdir_p(@extracted_dir)

    require "zip" # gem is require:false; only loaded during ZIP imports
    Zip::File.open(@zip_path) do |zip|
      zip.each do |entry|
        next if entry.directory?
        next if entry.name.start_with?("__MACOSX", ".")

        filename = File.basename(entry.name)
        next unless filename.match?(/\.(jpe?g|png|gif|webp)$/i)

        dest = File.join(@extracted_dir, filename)
        File.open(dest, "wb") { |f| f.write(entry.get_input_stream.read) }

        sku = extract_sku_from_filename(filename)
        next if sku.blank?

        @images_by_sku[sku] ||= []
        @images_by_sku[sku] << dest
      end
    end

    # Sort images for each SKU: numeric suffix first, then alphabetical
    @images_by_sku.each do |sku, paths|
      paths.sort_by! { |p| sort_key_for_image(File.basename(p)) }
    end
  end

  def load_images_from_dir
    return unless @images_dir.present? && File.directory?(@images_dir)

    Dir.glob(File.join(@images_dir, "*.{jpg,jpeg,png,gif,webp}")).each do |path|
      filename = File.basename(path)
      sku = extract_sku_from_filename(filename)
      next if sku.blank?

      @images_by_sku[sku] ||= []
      @images_by_sku[sku] << path
    end

    @images_by_sku.each do |sku, paths|
      paths.sort_by! { |p| sort_key_for_image(File.basename(p)) }
    end
  end

  def extract_sku_from_filename(filename)
    # Remove extension
    name = File.basename(filename, File.extname(filename))
    # SKU is everything before the first space (the rest is price info like 9price9)
    sku_part = name.split(/\s+/).first
    return nil if sku_part.blank?

    sku_part.downcase
  end

  # Try to find images for a product SKU, checking multiple normalizations
  def find_images_for_sku(sku)
    sku_down = sku.downcase
    # Try exact match first (handles SKUs like B16-9037)
    paths = @images_by_sku[sku_down] || @images_by_sku[sku_down.tr("/", "-")]
    return paths if paths.present?

    # Collect images where filename SKU matches after stripping numeric suffix
    # e.g., TEST-002-1.jpg and TEST-002-2.jpg both match SKU TEST-002
    normalized_sku = sku_down.tr("/", "-")
    matching = @images_by_sku.select do |key, _|
      stripped = key.sub(/-\d+$/, "")
      stripped == normalized_sku || stripped == sku_down
    end
    return nil if matching.empty?

    matching.values.flatten
  end

  def sort_key_for_image(filename)
    name = File.basename(filename, File.extname(filename))
    # Extract trailing number suffix (e.g., "-1", "-2")
    if name =~ /-(\d+)$/
      [$1.to_i, name]
    else
      [0, name]
    end
  end

  def attach_photos(product)
    sku = product.sku
    return 0 if sku.blank?

    image_paths = find_images_for_sku(sku) || []
    return 0 if image_paths.empty?

    # Replace existing photos if requested
    if @photo_mode == "replace" && product.photos.attached?
      product.photos.purge
    end

    count = 0
    image_paths.each do |path|
      next unless File.exist?(path)

      filename = File.basename(path)
      content_type = Marcel::MimeType.for(Pathname.new(path))

      product.photos.attach(
        io: File.open(path),
        filename: filename,
        content_type: content_type
      )
      count += 1
    end

    # Set first image as main photo if product has no main photo set
    if count > 0 && product.photos.any?
      first_attachment = product.photos.order(:id).first
      unless product.photos.any? { |p| p.blob.metadata["main"] }
        first_attachment.blob.update(metadata: first_attachment.blob.metadata.merge("main" => true))
      end
    end

    count
  end

  def attach_variant_photos(results)
    @organisation.product_variants.where.not(sku: [nil, ""]).where(is_default: false).find_each do |variant|
      sku = variant.sku.downcase
      normalized_sku = sku.tr("/:", "--")
      image_paths = @images_by_sku[sku] || @images_by_sku[normalized_sku]

      unless image_paths
        matching = @images_by_sku.select do |key, _|
          stripped = key.sub(/-\d+$/, "")
          stripped == normalized_sku || stripped == sku
        end
        image_paths = matching.values.flatten if matching.any?
      end

      next if image_paths.blank?

      path = image_paths.first
      next unless File.exist?(path)

      if @photo_mode == "replace" && variant.photo.attached?
        variant.photo.purge
        variant.reload
      end

      next if @photo_mode == "append" && variant.photo.attached?

      filename = File.basename(path)
      content_type = Marcel::MimeType.for(Pathname.new(path))
      variant.photo.attach(io: File.open(path), filename: filename, content_type: content_type)
      results[:photos_attached] += 1
    rescue => e
      results[:errors] << { row: nil, field: sku, message: e.message }
    end
  end

  def recalculate_availability
    stock_service = StockRulesService.new(@organisation)

    @imported_products.uniq.each do |product|
      product.product_variants.each do |variant|
        stock_service.apply_to_variant(variant)
      end
      stock_service.recalculate_product_availability(product.reload)
    end
  end

  def cleanup_extracted_images
    # Only clean up the temp extraction directory, not the source ZIP or uploaded images dir
    # Those are cleaned up by the controller after a successful import
    FileUtils.rm_rf(@extracted_dir) if @extracted_dir && File.exist?(@extracted_dir)
  end
end
