# frozen_string_literal: true

require "csv"

namespace :import do
  desc "Import product variations from WordPress CSV export"
  task :variations_from_csv, [:csv_path, :org_slug] => :environment do |t, args|
    csv_path = args[:csv_path]
    org_slug = args[:org_slug]

    unless csv_path && org_slug
      puts "Usage: rails 'import:variations_from_csv[path/to/file.csv,org-slug]'"
      exit 1
    end

    unless File.exist?(csv_path)
      puts "Error: CSV file not found at #{csv_path}"
      exit 1
    end

    organisation = Organisation.find_by(slug: org_slug)
    unless organisation
      puts "Error: Organisation '#{org_slug}' not found"
      exit 1
    end

    puts "Importing variations for organisation: #{organisation.name}"
    puts "-" * 60

    # Counters
    stats = {
      products_updated: 0,
      attributes_created: 0,
      attribute_values_created: 0,
      variants_created: 0,
      variants_updated: 0,
      skipped: 0,
      errors: []
    }

    # Cache for attributes and values
    attribute_cache = {}
    value_cache = {}

    # First pass: collect all unique attributes from variable products
    puts "\n[Phase 1] Collecting attributes from variable products..."
    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      next unless row["Tipo"] == "variable"

      4.times do |i|
        attr_name = row["Atributo #{i + 1} nome"]&.strip&.downcase
        next if attr_name.blank?

        unless attribute_cache[attr_name]
          attr = organisation.product_attributes.find_by(name: attr_name.titleize)
          unless attr
            slug = generate_unique_attr_slug(organisation, attr_name)
            attr = organisation.product_attributes.create!(name: attr_name.titleize, slug: slug, active: true)
            stats[:attributes_created] += 1
          end
          attribute_cache[attr_name] = attr
          puts "  Attribute: #{attr.name}"
        end

        # Collect all values for this attribute
        values_str = row["Atributo #{i + 1} valor(es)"]&.strip
        next if values_str.blank?

        values_str.split(",").map(&:strip).each do |val|
          next if val.blank?
          cache_key = "#{attr_name}:#{val.downcase}"
          unless value_cache[cache_key]
            attr = attribute_cache[attr_name]
            # Find existing or create new - handle slug uniqueness
            attr_val = attr.product_attribute_values.find_by(value: val)
            unless attr_val
              slug = generate_unique_slug(attr, val)
              attr_val = attr.product_attribute_values.create!(value: val, slug: slug, active: true)
              stats[:attribute_values_created] += 1
            end
            value_cache[cache_key] = attr_val
          end
        end
      end
    end

    puts "\n  Found #{attribute_cache.size} attributes, #{value_cache.size} values"

    # Second pass: process variable products and mark them as having variants
    puts "\n[Phase 2] Marking variable products..."
    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      next unless row["Tipo"] == "variable"

      sku = row["REF"]&.strip
      next if sku.blank?

      product = organisation.products.find_by(sku: sku)
      unless product
        puts "  NOT FOUND: #{sku}"
        stats[:skipped] += 1
        next
      end

      # Mark as variable product
      unless product.has_variants?
        product.update!(has_variants: true)
        stats[:products_updated] += 1
        puts "  UPDATED: #{sku} -> has_variants: true"
      end

      # Link product to its attributes
      4.times do |i|
        attr_name = row["Atributo #{i + 1} nome"]&.strip&.downcase
        next if attr_name.blank?

        attr = attribute_cache[attr_name]
        next unless attr

        unless product.product_attributes.include?(attr)
          product.product_product_attributes.find_or_create_by!(product_attribute: attr)
        end

        # Link available values
        values_str = row["Atributo #{i + 1} valor(es)"]&.strip
        next if values_str.blank?

        values_str.split(",").map(&:strip).each do |val|
          next if val.blank?
          cache_key = "#{attr_name}:#{val.downcase}"
          attr_val = value_cache[cache_key]
          next unless attr_val

          unless product.available_attribute_values.include?(attr_val)
            product.product_available_values.find_or_create_by!(product_attribute_value: attr_val)
          end
        end
      end
    end

    # Third pass: create variations
    puts "\n[Phase 3] Creating product variants..."
    CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
      next unless row["Tipo"] == "variation"

      parent_sku = row["Pai"]&.strip
      if parent_sku.blank?
        stats[:skipped] += 1
        next
      end

      product = organisation.products.find_by(sku: parent_sku)
      unless product
        puts "  PARENT NOT FOUND: #{parent_sku}"
        stats[:skipped] += 1
        next
      end

      # Extract variation data
      var_sku = row["REF"]&.strip
      var_name = row["Nome"]&.strip || product.name
      var_price = parse_price(row["Preço normal"])

      # Collect attribute values for this variation
      attr_values = []
      4.times do |i|
        attr_name = row["Atributo #{i + 1} nome"]&.strip&.downcase
        attr_value_str = row["Atributo #{i + 1} valor(es)"]&.strip
        next if attr_name.blank? || attr_value_str.blank?

        cache_key = "#{attr_name}:#{attr_value_str.downcase}"
        attr_val = value_cache[cache_key]

        # Try to find or create if not in cache
        unless attr_val
          attr = attribute_cache[attr_name]
          if attr
            attr_val = attr.product_attribute_values.find_by(value: attr_value_str)
            unless attr_val
              slug = generate_unique_slug(attr, attr_value_str)
              attr_val = attr.product_attribute_values.create!(value: attr_value_str, slug: slug, active: true)
            end
            value_cache[cache_key] = attr_val
          end
        end

        attr_values << attr_val if attr_val
      end

      # Skip if no attribute values (can't create meaningful variant)
      if attr_values.empty?
        puts "  SKIP: #{var_name} - no attribute values"
        stats[:skipped] += 1
        next
      end

      # Find existing variant by attribute combination or create new
      existing_variant = find_variant_by_attributes(product, attr_values)

      if existing_variant
        # Update existing variant
        updates = {}
        updates[:unit_price_cents] = var_price if var_price && existing_variant.unit_price_cents != var_price
        updates[:sku] = var_sku if var_sku.present? && existing_variant.sku.blank?

        if updates.any?
          existing_variant.update!(updates)
          stats[:variants_updated] += 1
          puts "  UPDATED: #{var_name} (#{attr_values.map(&:value).join(' / ')})"
        else
          stats[:skipped] += 1
        end
      else
        # Create new variant
        begin
          variant = product.product_variants.create!(
            name: var_name,
            sku: var_sku.presence,
            unit_price_cents: var_price,
            unit_price_currency: organisation.currency,
            available: true,
            is_default: false,
            organisation: organisation
          )

          # Link attribute values
          attr_values.each do |av|
            variant.variant_attribute_values.create!(product_attribute_value: av)
          end

          stats[:variants_created] += 1
          price_str = var_price ? Money.new(var_price, organisation.currency).format : "no price"
          puts "  CREATED: #{var_name} (#{attr_values.map(&:value).join(' / ')}) - #{price_str}"
        rescue => e
          stats[:errors] << { name: var_name, error: e.message }
          puts "  ERROR: #{var_name} - #{e.message}"
        end
      end
    end

    # Summary
    puts "\n" + "-" * 60
    puts "Import complete!"
    puts "  Products updated:       #{stats[:products_updated]}"
    puts "  Attributes created:     #{stats[:attributes_created]}"
    puts "  Attribute values:       #{stats[:attribute_values_created]}"
    puts "  Variants created:       #{stats[:variants_created]}"
    puts "  Variants updated:       #{stats[:variants_updated]}"
    puts "  Skipped:                #{stats[:skipped]}"
    puts "  Errors:                 #{stats[:errors].size}"

    if stats[:errors].any?
      puts "\nErrors:"
      stats[:errors].first(10).each do |err|
        puts "  - #{err[:name]}: #{err[:error]}"
      end
      puts "  ... and #{stats[:errors].size - 10} more" if stats[:errors].size > 10
    end
  end

  private

  def generate_unique_attr_slug(organisation, attr_name)
    base_slug = attr_name.parameterize
    base_slug = "attr-#{SecureRandom.hex(4)}" if base_slug.blank?
    slug = base_slug
    counter = 1

    while organisation.product_attributes.exists?(slug: slug)
      counter += 1
      slug = "#{base_slug}-#{counter}"
    end

    slug
  end

  def generate_unique_slug(attribute, value)
    base_slug = value.parameterize
    base_slug = "value-#{SecureRandom.hex(4)}" if base_slug.blank?
    slug = base_slug
    counter = 1

    while attribute.product_attribute_values.exists?(slug: slug)
      counter += 1
      slug = "#{base_slug}-#{counter}"
    end

    slug
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

  def find_variant_by_attributes(product, attr_values)
    return nil if attr_values.empty?

    attr_value_ids = attr_values.map(&:id).sort

    product.product_variants.find do |variant|
      variant.attribute_values.pluck(:id).sort == attr_value_ids
    end
  end
end
