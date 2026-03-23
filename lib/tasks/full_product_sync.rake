# frozen_string_literal: true

require "csv"

namespace :sync do
  desc "Full product sync from cleaned CSV - CSV is source of truth"
  task :full_product_sync, [:csv_path, :org_slug, :mode] => :environment do |_t, args|
    csv_path = args[:csv_path]
    org_slug = args[:org_slug]
    mode = args[:mode] || "dry_run"

    unless csv_path && org_slug
      puts "Usage:"
      puts "  rails 'sync:full_product_sync[path/to/file.csv,org-slug,dry_run]'"
      puts "  rails 'sync:full_product_sync[path/to/file.csv,org-slug,execute]'"
      exit 1
    end

    unless File.exist?(csv_path)
      puts "Error: CSV file not found at #{csv_path}"
      exit 1
    end

    org = Organisation.find_by(slug: org_slug)
    unless org
      puts "Error: Organisation '#{org_slug}' not found"
      exit 1
    end

    dry_run = mode == "dry_run"

    puts "=" * 70
    puts dry_run ? "FULL PRODUCT SYNC (DRY RUN)" : "FULL PRODUCT SYNC (EXECUTE)"
    puts "Organisation: #{org.name} (#{org.slug})"
    puts "CSV: #{csv_path}"
    puts "=" * 70

    # ═══════════════════════════════════════════════════════════════════════
    # PHASE 1: Parse CSV
    # ═══════════════════════════════════════════════════════════════════════
    puts "\n[Phase 1] Parsing CSV...\n"

    csv_products = {}      # SKU => row (simple/variable)
    csv_variations = {}    # Parent SKU => [rows]
    csv_attr_values = Hash.new { |h, k| h[k] = Set.new }  # attr_name => Set of values

    rows = CSV.read(csv_path, headers: true, liberal_parsing: true)
    rows.each do |row|
      tipo = row["Tipo"]&.strip
      next unless %w[simple variable variation].include?(tipo)

      # Collect attribute values
      4.times do |i|
        attr_name = row["Atributo #{i + 1} nome"]&.strip
        attr_vals = row["Atributo #{i + 1} valor(es)"]&.strip
        next if attr_name.blank? || attr_vals.blank?
        attr_vals.split(", ").each { |v| csv_attr_values[attr_name] << v.strip }
      end

      if tipo == "variation"
        parent_sku = row["Pai"]&.strip
        next if parent_sku.blank?
        csv_variations[parent_sku] ||= []
        csv_variations[parent_sku] << row
      else
        sku = row["REF"]&.strip
        next if sku.blank?
        csv_products[sku] = row
      end
    end

    simple_count = csv_products.values.count { |r| r["Tipo"] == "simple" }
    variable_count = csv_products.values.count { |r| r["Tipo"] == "variable" }
    variation_count = csv_variations.values.sum(&:size)

    puts "  Products: #{csv_products.size} (#{simple_count} simple, #{variable_count} variable)"
    puts "  Variations: #{variation_count}"
    puts "  Attributes: #{csv_attr_values.keys.join(', ')}"

    # ═══════════════════════════════════════════════════════════════════════
    # PHASE 2: Build attribute value normalization map
    # ═══════════════════════════════════════════════════════════════════════
    puts "\n[Phase 2] Checking attribute value normalization...\n"

    # Build map of CSV values for each attribute
    normalization_map = {}  # { attr_name => { db_value => csv_value } }

    org.product_attributes.each do |attr|
      csv_values = csv_attr_values[attr.name] || Set.new
      next if csv_values.empty?

      attr.product_attribute_values.each do |av|
        db_val = av.value
        # Try to find matching CSV value (case-insensitive, whitespace-normalized)
        csv_match = csv_values.find do |cv|
          normalize_for_compare(cv) == normalize_for_compare(db_val)
        end

        if csv_match && csv_match != db_val
          normalization_map[attr.name] ||= {}
          normalization_map[attr.name][db_val] = csv_match
        end
      end
    end

    if normalization_map.any?
      puts "  Values to normalize:"
      normalization_map.each do |attr_name, mappings|
        mappings.each do |old_val, new_val|
          puts "    #{attr_name}: '#{old_val}' → '#{new_val}'"
        end
      end
    else
      puts "  No normalization needed"
    end

    # ═══════════════════════════════════════════════════════════════════════
    # PHASE 3: Analyze products
    # ═══════════════════════════════════════════════════════════════════════
    puts "\n[Phase 3] Analyzing products...\n"

    db_products = org.products.includes(:product_variants).index_by(&:sku)

    product_changes = {
      create: [],      # { sku:, row: } — products in CSV but not in DB
      update: [],      # { product:, changes: { field: [old, new] } }
      not_in_csv: []   # SKUs in DB but not in CSV
    }

    # Check CSV products against DB
    csv_products.each do |sku, row|
      db_product = db_products[sku]

      unless db_product
        product_changes[:create] << { sku: sku, row: row }
        next
      end

      changes = {}

      csv_name = row["Nome"]&.strip
      if csv_name.present? && db_product.name != csv_name
        changes[:name] = [db_product.name, csv_name]
      end

      csv_desc = row["Descrição breve"]&.strip
      if csv_desc.present? && db_product.description != csv_desc
        changes[:description] = [db_product.description, csv_desc]
      end

      csv_has_variants = row["Tipo"] == "variable"
      if db_product.has_variants? != csv_has_variants
        changes[:has_variants] = [db_product.has_variants?, csv_has_variants]
      end

      # Price for simple products
      if row["Tipo"] == "simple"
        csv_price = parse_price(row["Preço normal"])
        if csv_price && db_product.unit_price != csv_price
          changes[:unit_price] = [db_product.unit_price, csv_price]
        end
      end

      product_changes[:update] << { product: db_product, changes: changes } if changes.any?
    end

    # Find products in DB but not in CSV
    db_products.each_key do |sku|
      product_changes[:not_in_csv] << sku unless csv_products[sku]
    end

    puts "  Products to create: #{product_changes[:create].size}"
    puts "  Products to update: #{product_changes[:update].size}"
    puts "  In DB but not CSV: #{product_changes[:not_in_csv].size}"

    if product_changes[:create].any?
      simple_to_create = product_changes[:create].count { |c| c[:row]["Tipo"] == "simple" }
      variable_to_create = product_changes[:create].count { |c| c[:row]["Tipo"] == "variable" }
      puts "    To create: #{simple_to_create} simple, #{variable_to_create} variable"
    end

    # ═══════════════════════════════════════════════════════════════════════
    # PHASE 4: Analyze variations
    # ═══════════════════════════════════════════════════════════════════════
    puts "\n[Phase 4] Analyzing variations...\n"

    variation_changes = {
      create: [],     # { parent:, attrs:, name:, price: }
      update: [],     # { variant:, changes: }
      delete: [],     # variants to delete
      orphan: []      # variations in CSV with missing parent
    }

    # For each variable product, analyze its variations
    csv_products.each do |sku, row|
      next unless row["Tipo"] == "variable"

      db_product = db_products[sku]
      next unless db_product

      csv_vars = csv_variations[sku] || []

      # Build map of CSV variations by attribute key
      csv_var_map = {}
      csv_vars.each do |var_row|
        attrs = extract_attrs(var_row)
        key = build_attr_key(attrs)
        csv_var_map[key] = var_row
      end

      # Check each DB variant
      matched_keys = Set.new
      db_product.product_variants.each do |db_variant|
        next if db_variant.is_default?

        db_attrs = db_variant.attribute_values.includes(:product_attribute).map do |av|
          # Apply normalization
          attr_name = av.product_attribute.name
          val = av.value
          if normalization_map[attr_name]&.key?(val)
            val = normalization_map[attr_name][val]
          end
          [attr_name, val]
        end.to_h

        key = build_attr_key(db_attrs)
        csv_row = csv_var_map[key]

        if csv_row
          matched_keys << key
          changes = {}

          csv_name = csv_row["Nome"]&.strip
          if csv_name.present? && db_variant.name != csv_name
            changes[:name] = [db_variant.name, csv_name]
          end

          csv_price = parse_price(csv_row["Preço normal"])
          if csv_price && db_variant.unit_price_cents != csv_price
            changes[:unit_price_cents] = [db_variant.unit_price_cents, csv_price]
          end

          variation_changes[:update] << { variant: db_variant, changes: changes } if changes.any?
        else
          # Variant in DB but not in CSV - mark for deletion
          variation_changes[:delete] << db_variant
        end
      end

      # Check for CSV variations not in DB (need to create)
      csv_var_map.each do |key, var_row|
        next if matched_keys.include?(key)

        attrs = extract_attrs(var_row)
        variation_changes[:create] << {
          parent: db_product,
          attrs: attrs,
          name: var_row["Nome"]&.strip,
          price: parse_price(var_row["Preço normal"]),
          sku: var_row["REF"]&.strip
        }
      end
    end

    # Count variations that will be created along with new parent products
    new_product_skus = product_changes[:create].map { |c| c[:sku] }.to_set
    new_product_variations = 0

    # Check for orphan variations (parent not in DB AND not being created)
    csv_variations.each do |parent_sku, vars|
      next if db_products[parent_sku]
      if new_product_skus.include?(parent_sku)
        new_product_variations += vars.size
      else
        variation_changes[:orphan] << { parent_sku: parent_sku, count: vars.size }
      end
    end

    puts "  Variants to update: #{variation_changes[:update].size}"
    puts "  Variants to create (existing products): #{variation_changes[:create].size}"
    puts "  Variants to create (new products): #{new_product_variations}"
    puts "  Variants to delete: #{variation_changes[:delete].size}"
    puts "  Orphan variations (parent missing): #{variation_changes[:orphan].any? ? variation_changes[:orphan].sum { |o| o[:count] } : 0}"

    # Show some examples
    if dry_run
      if variation_changes[:delete].any?
        puts "\n  Variants to DELETE (first 10):"
        variation_changes[:delete].first(10).each do |v|
          attrs = v.attribute_values.map { |av| "#{av.product_attribute.name}=#{av.value}" }.join("|")
          puts "    - #{v.product.sku}/#{v.name} (#{attrs.presence || 'NO ATTRS'})"
        end
        puts "    ... and #{variation_changes[:delete].size - 10} more" if variation_changes[:delete].size > 10
      end

      if variation_changes[:create].any?
        puts "\n  Variants to CREATE (first 10):"
        variation_changes[:create].first(10).each do |c|
          attrs = c[:attrs].map { |k, v| "#{k}=#{v}" }.join("|")
          puts "    - #{c[:parent].sku}/#{c[:name]} (#{attrs}) - €#{c[:price].to_f / 100}"
        end
        puts "    ... and #{variation_changes[:create].size - 10} more" if variation_changes[:create].size > 10
      end
    end

    # ═══════════════════════════════════════════════════════════════════════
    # DRY RUN SUMMARY
    # ═══════════════════════════════════════════════════════════════════════
    if dry_run
      puts "\n" + "=" * 70
      puts "DRY RUN SUMMARY"
      puts "=" * 70
      puts "Products:"
      puts "  - #{product_changes[:create].size} to CREATE"
      puts "  - #{product_changes[:update].size} to update"
      puts "  - #{product_changes[:not_in_csv].size} in DB but not in CSV (untouched)"
      puts ""
      puts "Variants:"
      puts "  - #{variation_changes[:update].size} to update"
      puts "  - #{variation_changes[:create].size} to create (existing products)"
      puts "  - #{new_product_variations} to create (new products)"
      puts "  - #{variation_changes[:delete].size} to delete"
      puts ""
      puts "Attribute value normalizations: #{normalization_map.values.sum(&:size)}"
      puts ""
      puts "Run with mode=execute to apply changes."
      puts "=" * 70
      next
    end

    # ═══════════════════════════════════════════════════════════════════════
    # EXECUTE MODE
    # ═══════════════════════════════════════════════════════════════════════
    puts "\n[Executing changes...]\n"

    stats = {
      attr_values_normalized: 0,
      products_created: 0,
      products_updated: 0,
      variants_updated: 0,
      variants_created: 0,
      variants_deleted: 0,
      errors: []
    }

    ActiveRecord::Base.transaction do
      # Step 1: Normalize attribute values
      puts "\n  Normalizing attribute values..."
      normalization_map.each do |attr_name, mappings|
        attr = org.product_attributes.find_by(name: attr_name)
        next unless attr

        mappings.each do |old_val, new_val|
          av = attr.product_attribute_values.find_by(value: old_val)
          next unless av

          # Check if target value already exists
          existing = attr.product_attribute_values.find_by(value: new_val)
          if existing && existing.id != av.id
            # Merge: move all variant associations to existing, then delete
            av.variant_attribute_values.update_all(product_attribute_value_id: existing.id)
            av.destroy!
          else
            av.update!(value: new_val)
          end
          stats[:attr_values_normalized] += 1
        end
      end

      # Step 2: Update products
      puts "  Updating products..."
      product_changes[:update].each do |item|
        product = item[:product]
        changes = item[:changes]

        attrs = {}
        changes.each { |field, (_, new_val)| attrs[field] = new_val }

        begin
          product.update!(attrs)
          stats[:products_updated] += 1
        rescue => e
          stats[:errors] << "Product #{product.sku}: #{e.message}"
        end
      end

      # Step 2b: Rebuild available values for existing variable products
      puts "  Rebuilding available values for existing variable products..."
      rebuilt_count = 0
      csv_products.each do |sku, row|
        next unless row["Tipo"] == "variable"
        product = db_products[sku]
        next unless product

        product.product_available_values.delete_all
        product.product_product_attributes.delete_all

        4.times do |i|
          attr_name = row["Atributo #{i + 1} nome"]&.strip
          attr_vals_str = row["Atributo #{i + 1} valor(es)"]&.strip
          next if attr_name.blank? || attr_vals_str.blank?

          attr = org.product_attributes.find_or_create_by!(name: attr_name) do |a|
            a.slug = attr_name.parameterize
          end

          product.product_product_attributes.find_or_create_by!(product_attribute: attr)

          attr_vals_str.split(", ").each do |val_str|
            val = val_str.strip
            next if val.blank?
            av = attr.product_attribute_values.find_or_create_by!(value: val)
            product.product_available_values.find_or_create_by!(product_attribute_value: av)
          end
        end
        rebuilt_count += 1
      end
      puts "    Rebuilt available values for #{rebuilt_count} variable products"

      # Step 3: Create new products
      puts "  Creating new products..."
      created_products = {} # sku => product (for variation linking)
      product_changes[:create].each do |item|
        row = item[:row]
        sku = item[:sku]
        begin
          is_variable = row["Tipo"] == "variable"
          csv_price = parse_price(row["Preço normal"])

          product = org.products.create!(
            name: row["Nome"]&.strip,
            sku: sku,
            description: row["Descrição breve"]&.strip,
            unit_price: is_variable ? nil : csv_price,
            has_variants: is_variable,
            available: true
          )
          created_products[sku] = product

          # For variable products, set up product attributes and available values
          if is_variable
            4.times do |i|
              attr_name = row["Atributo #{i + 1} nome"]&.strip
              attr_vals_str = row["Atributo #{i + 1} valor(es)"]&.strip
              next if attr_name.blank? || attr_vals_str.blank?

              attr = org.product_attributes.find_or_create_by!(name: attr_name) do |a|
                a.slug = attr_name.parameterize
              end

              # Link attribute to product
              product.product_product_attributes.find_or_create_by!(product_attribute: attr)

              # Create and link available values
              attr_vals_str.split(", ").each do |val_str|
                val = val_str.strip
                next if val.blank?

                av = attr.product_attribute_values.find_or_create_by!(value: val)
                product.product_available_values.find_or_create_by!(product_attribute_value: av)
              end
            end
          end

          # Update the default variant's price for simple products
          if !is_variable && csv_price
            default_variant = product.default_variant
            default_variant&.update!(unit_price_cents: csv_price)
          end

          stats[:products_created] += 1
          puts "    Created: #{sku} - #{product.name} (#{row['Tipo']})"
        rescue => e
          stats[:errors] << "Create product #{sku}: #{e.message}"
          puts "    ERROR: #{sku} - #{e.message}"
        end
      end

      # Step 3b: Create variations for newly created products
      puts "  Creating variations for new products..."
      created_products.each do |parent_sku, parent_product|
        csv_vars = csv_variations[parent_sku] || []
        csv_vars.each do |var_row|
          begin
            attrs = extract_attrs(var_row)
            var_price = parse_price(var_row["Preço normal"])

            variant = parent_product.product_variants.create!(
              name: var_row["Nome"]&.strip || parent_product.name,
              sku: var_row["REF"]&.strip.presence,
              unit_price_cents: var_price,
              unit_price_currency: org.currency,
              available: true,
              is_default: false,
              organisation: org
            )

            attrs.each do |attr_name, attr_val|
              attr = org.product_attributes.find_by(name: attr_name)
              next unless attr

              av = attr.product_attribute_values.find_or_create_by!(value: attr_val)
              variant.variant_attribute_values.create!(product_attribute_value: av)
            end

            stats[:variants_created] += 1
          rescue => e
            stats[:errors] << "Create variant #{var_row['REF']} for #{parent_sku}: #{e.message}"
            puts "    ERROR: #{var_row['REF']} - #{e.message}"
          end
        end
      end

      # Step 4: Update existing variants
      puts "  Updating variants..."
      variation_changes[:update].each do |item|
        variant = item[:variant]
        changes = item[:changes]

        attrs = {}
        changes.each { |field, (_, new_val)| attrs[field] = new_val }

        begin
          variant.update!(attrs)
          stats[:variants_updated] += 1
        rescue => e
          stats[:errors] << "Variant #{variant.product.sku}/#{variant.name}: #{e.message}"
        end
      end

      # Step 5: Delete orphan variants (before creating new ones to free up SKUs)
      puts "  Deleting orphan variants..."
      variation_changes[:delete].each do |variant|
        begin
          if variant.order_items.any?
            stats[:errors] << "Cannot delete #{variant.product.sku}/#{variant.name} - has orders"
          else
            variant.destroy!
            stats[:variants_deleted] += 1
          end
        rescue => e
          stats[:errors] << "Delete variant #{variant.product.sku}/#{variant.name}: #{e.message}"
        end
      end

      # Step 6: Create new variants (for existing products — after deletes freed up SKUs)
      puts "  Creating variants for existing products..."
      variation_changes[:create].each do |item|
        begin
          variant = item[:parent].product_variants.create!(
            name: item[:name] || item[:parent].name,
            sku: item[:sku].presence,
            unit_price_cents: item[:price],
            unit_price_currency: org.currency,
            available: true,
            is_default: false,
            organisation: org
          )

          # Link attribute values
          item[:attrs].each do |attr_name, attr_val|
            attr = org.product_attributes.find_by(name: attr_name)
            next unless attr

            av = attr.product_attribute_values.find_or_create_by!(value: attr_val)
            variant.variant_attribute_values.create!(product_attribute_value: av)
          end

          stats[:variants_created] += 1
        rescue => e
          stats[:errors] << "Create variant for #{item[:parent].sku}: #{e.message}"
        end
      end
    end

    # ═══════════════════════════════════════════════════════════════════════
    # FINAL SUMMARY
    # ═══════════════════════════════════════════════════════════════════════
    puts "\n" + "=" * 70
    puts "SYNC COMPLETE"
    puts "=" * 70
    puts "Attribute values normalized: #{stats[:attr_values_normalized]}"
    puts "Products created: #{stats[:products_created]}"
    puts "Products updated: #{stats[:products_updated]}"
    puts "Variants updated: #{stats[:variants_updated]}"
    puts "Variants created: #{stats[:variants_created]}"
    puts "Variants deleted: #{stats[:variants_deleted]}"
    puts "Errors: #{stats[:errors].size}"

    if stats[:errors].any?
      puts "\nErrors (first 20):"
      stats[:errors].first(20).each { |e| puts "  - #{e}" }
      puts "  ... and #{stats[:errors].size - 20} more" if stats[:errors].size > 20
    end
    puts "=" * 70
  end
end

# Helper methods defined as module functions
def normalize_for_compare(value)
  value.to_s.downcase.gsub(/\s+/, "").strip
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

def extract_attrs(row)
  attrs = {}
  4.times do |i|
    name = row["Atributo #{i + 1} nome"]&.strip
    val = row["Atributo #{i + 1} valor(es)"]&.strip
    attrs[name] = val if name.present? && val.present?
  end
  attrs
end

def build_attr_key(attrs)
  attrs.sort.map { |k, v| "#{k}:#{v}" }.join("|")
end
