class ProductGridImportService
  NUM_ATTRS = 3

  Result = Struct.new(
    :products_created, :products_updated, :variants_created, :attributes_created,
    :attribute_values_created, :photos_attached, :errors, :total,
    keyword_init: true
  )

  def initialize(organisation:, rows:, zip_path: nil, images_dir: nil, photo_mode: "append")
    @organisation = organisation
    @rows = rows
    @zip_path = zip_path
    @images_dir = images_dir
    @photo_mode = photo_mode
    @errors = []
    @images_by_sku = {}
    @stats = {
      products_created: 0,
      products_updated: 0,
      variants_created: 0,
      attributes_created: 0,
      attribute_values_created: 0,
      photos_attached: 0
    }
    @created_products = {} # sku => product
  end

  def call
    extract_images_from_zip if @zip_path.present?
    load_images_from_dir if @images_dir.present?

    ActiveRecord::Base.transaction do
      simple_rows, variable_rows, variation_rows = separate_rows

      create_simple_products(simple_rows)
      create_variable_products(variable_rows)
      create_variations(variation_rows)
      backfill_variable_available_values

      if @errors.any?
        @stats = { products_created: 0, products_updated: 0, variants_created: 0,
                   attributes_created: 0, attribute_values_created: 0, photos_attached: 0 }
        raise ActiveRecord::Rollback
      end
    end

    # Attach photos outside the transaction (same pattern as ProductImportService)
    attach_all_photos if @errors.empty?

    # Recalculate stock-based availability for all created/updated products
    recalculate_availability if @errors.empty?

    Result.new(
      **@stats,
      errors: @errors,
      total: @stats[:products_created] + @stats[:products_updated] + @stats[:variants_created]
    )
  ensure
    cleanup_extracted_images
  end

  private

  def separate_rows
    simple = []
    variable = []
    variation = []

    @rows.each_with_index do |row, index|
      case row["tipo"]
      when "simple" then simple << { data: row, line: index + 1 }
      when "variable" then variable << { data: row, line: index + 1 }
      when "variation" then variation << { data: row, line: index + 1 }
      else
        @errors << { row: index + 1, field: "tipo", message: "Tipo inv\u00E1lido: '#{row['tipo']}'" }
      end
    end

    [simple, variable, variation]
  end

  def create_simple_products(rows)
    rows.each do |item|
      row = item[:data]
      line = item[:line]

      begin
        product = find_or_initialize_product(row["sku"])
        was_new = product.new_record?

        product.assign_attributes(
          name: row["nome"],
          description: row["descricao"].presence,
          unit_price: parse_price(row["preco"]),
          has_variants: false,
          published: true
        )
        product.organisation = @organisation unless product.persisted?

        product.save!
        assign_category(product, row["categoria"])
        setup_simple_product_attributes(product, row)

        @created_products[row["sku"]] = product if row["sku"].present?
        was_new ? @stats[:products_created] += 1 : @stats[:products_updated] += 1
      rescue ActiveRecord::RecordInvalid => e
        @errors << { row: line, field: nil, message: e.message }
      rescue StandardError => e
        @errors << { row: line, field: nil, message: e.message }
      end
    end
  end

  def create_variable_products(rows)
    rows.each do |item|
      row = item[:data]
      line = item[:line]

      begin
        product = find_or_initialize_product(row["sku"])
        was_new = product.new_record?

        product.assign_attributes(
          name: row["nome"],
          description: row["descricao"].presence,
          has_variants: true,
          published: true
        )
        product.organisation = @organisation unless product.persisted?

        product.save!
        assign_category(product, row["categoria"])
        setup_variable_product_attributes(product, row, line)

        @created_products[row["sku"]] = product if row["sku"].present?
        was_new ? @stats[:products_created] += 1 : @stats[:products_updated] += 1
      rescue ActiveRecord::RecordInvalid => e
        @errors << { row: line, field: nil, message: e.message }
      rescue StandardError => e
        @errors << { row: line, field: nil, message: e.message }
      end
    end
  end

  def create_variations(rows)
    rows.each do |item|
      row = item[:data]
      line = item[:line]

      begin
        parent = find_parent_product(row["sku_pai"])
        unless parent
          @errors << { row: line, field: "sku_pai", message: "Produto pai '#{row['sku_pai']}' n\u00E3o encontrado" }
          next
        end

        # Upsert variant by SKU
        variant_sku = row["sku"].presence
        if variant_sku
          variant = @organisation.product_variants.find_by(sku: variant_sku)
        end

        if variant
          variant.assign_attributes(
            name: row["nome"],
            unit_price_cents: parse_price(row["preco"]) || variant.unit_price_cents,
            product: parent
          )
        else
          variant = parent.product_variants.new(
            name: row["nome"],
            sku: variant_sku,
            unit_price_cents: parse_price(row["preco"]),
            unit_price_currency: @organisation.currency,
            published: true,
            is_default: false,
            organisation: @organisation
          )
        end
        variant.save!

        # Re-link attribute values (clear and re-create)
        variant.variant_attribute_values.destroy_all
        link_variant_attributes(variant, row, line)

        # Inherit category from parent
        if row["categoria"].blank?
          parent.categories.each do |cat|
            # Categories belong to the product, not the variant, so nothing to do here
            # The variation inherits the parent's category implicitly
          end
        end

        @stats[:variants_created] += 1
      rescue ActiveRecord::RecordInvalid => e
        @errors << { row: line, field: nil, message: e.message }
      rescue StandardError => e
        @errors << { row: line, field: nil, message: e.message }
      end
    end
  end

  def setup_simple_product_attributes(product, row)
    variant = product.default_variant

    NUM_ATTRS.times do |i|
      attr_name = row["atributo_#{i + 1}_nome"]
      attr_value = row["atributo_#{i + 1}_valores"]
      next if attr_name.blank? || attr_value.blank?

      attribute = find_or_create_attribute(attr_name)

      # Link attribute to product
      product.product_product_attributes.find_or_create_by!(product_attribute: attribute)

      # Create the single value
      av = attribute.product_attribute_values.find_or_create_by!(value: attr_value.strip)
      @stats[:attribute_values_created] += 1 if av.previously_new_record?

      # For simple products, set the available value too
      product.product_available_values.find_or_create_by!(product_attribute_value: av)

      # Also assign to the default variant so attributes display correctly
      variant&.variant_attribute_values&.find_or_create_by!(product_attribute_value: av)
    end
  end

  def setup_variable_product_attributes(product, row, _line)
    product.product_product_attributes.delete_all

    NUM_ATTRS.times do |i|
      attr_name = row["atributo_#{i + 1}_nome"]
      next if attr_name.blank?

      attribute = find_or_create_attribute(attr_name)
      product.product_product_attributes.find_or_create_by!(product_attribute: attribute)
    end
    # product_available_values are backfilled after variations are created
  end

  def backfill_variable_available_values
    # For all variable products in the org, ensure available values match variant data
    @organisation.products.where(has_variants: true)
       .includes(:product_attributes, :product_available_values, product_variants: :attribute_values)
       .find_each do |product|
      variant_value_ids = product.product_variants.reject(&:is_default?).select(&:published?)
                                 .flat_map { |v| v.attribute_values.map(&:id) }.uniq
      existing_ids = product.product_available_values.pluck(:product_attribute_value_id)
      missing_ids = variant_value_ids - existing_ids
      next if missing_ids.empty?

      ProductAttributeValue.where(id: missing_ids).includes(:product_attribute).each do |val|
        attr = val.product_attribute
        unless product.product_attributes.include?(attr)
          product.product_product_attributes.create!(product_attribute: attr)
          product.reload
        end
        product.product_available_values.find_or_create_by!(product_attribute_value: val)
      end
    end
  end

  def link_variant_attributes(variant, row, line)
    NUM_ATTRS.times do |i|
      attr_name = row["atributo_#{i + 1}_nome"]
      attr_val = row["atributo_#{i + 1}_valores"]
      next if attr_name.blank? || attr_val.blank?

      attribute = @organisation.product_attributes.find_by(name: attr_name)
      unless attribute
        @errors << { row: line, field: "atributo_#{i + 1}_nome", message: "Atributo '#{attr_name}' n\u00E3o encontrado" }
        next
      end

      av = attribute.product_attribute_values.find_or_create_by!(value: attr_val.strip)
      @stats[:attribute_values_created] += 1 if av.previously_new_record?

      variant.variant_attribute_values.create!(product_attribute_value: av)
    end
  end

  def find_or_create_attribute(name)
    attribute = @organisation.product_attributes.find_or_create_by!(name: name) do |a|
      a.slug = name.parameterize
    end
    @stats[:attributes_created] += 1 if attribute.previously_new_record?
    attribute
  end

  def find_or_initialize_product(sku)
    if sku.present?
      @organisation.products.find_or_initialize_by(sku: sku)
    else
      @organisation.products.new
    end
  end

  def find_parent_product(sku_pai)
    return nil if sku_pai.blank?
    @created_products[sku_pai] || @organisation.products.find_by(sku: sku_pai)
  end

  def assign_category(product, category_name)
    return if category_name.blank?

    # The grid sends full_path (e.g., "Moldura Prata > Criança"), match against it
    category = category_lookup[category_name.downcase.strip]
    return unless category

    product.categories << category unless product.categories.include?(category)
  end

  def category_lookup
    @category_lookup ||= @organisation.categories.kept.index_by { |c| c.full_path.downcase.strip }
  end

  def parse_price(value)
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

  # ─── Photo handling (reused from ProductImportService) ─────

  def attach_all_photos
    return if @images_by_sku.empty?

    # Attach to products
    @created_products.each do |_sku, product|
      @stats[:photos_attached] += attach_photos(product)
    end

    # Attach to variants
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
      @stats[:photos_attached] += 1
    end
  end

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

    @images_by_sku.each { |_sku, paths| paths.sort_by! { |p| sort_key_for_image(File.basename(p)) } }
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

    @images_by_sku.each { |_sku, paths| paths.sort_by! { |p| sort_key_for_image(File.basename(p)) } }
  end

  def extract_sku_from_filename(filename)
    name = File.basename(filename, File.extname(filename))
    sku_part = name.split(/\s+/).first
    return nil if sku_part.blank?
    sku_part.downcase
  end

  def find_images_for_sku(sku)
    sku_down = sku.downcase
    paths = @images_by_sku[sku_down] || @images_by_sku[sku_down.tr("/", "-")]
    return paths if paths.present?

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

    if @photo_mode == "replace" && product.photos.attached?
      product.photos.purge
      product.reload
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

    if count > 0 && product.photos.any?
      first_attachment = product.photos_attachments.order(:id).first
      unless product.photos.any? { |p| p.blob.metadata["main"] }
        first_attachment.blob.update(metadata: first_attachment.blob.metadata.merge("main" => true))
      end
    end

    count
  end

  def recalculate_availability
    stock_service = StockRulesService.new(@organisation)

    @created_products.each_value do |product|
      product.product_variants.each do |variant|
        stock_service.apply_to_variant(variant)
      end
      stock_service.recalculate_product_availability(product.reload)
    end
  end

  def cleanup_extracted_images
    FileUtils.rm_rf(@extracted_dir) if @extracted_dir && File.exist?(@extracted_dir)
  end
end
