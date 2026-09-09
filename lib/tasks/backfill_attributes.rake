require "csv"

namespace :attributes do
  desc "Extract attribute suggestions from product names/descriptions using LLM, output CSV for review"
  task :extract, [:org_slug, :output_csv] => :environment do |_t, args|
    org_slug = args[:org_slug] || "perestrelo-cunha"
    output_csv = args[:output_csv] || "products_attributes_review.csv"

    org = Organisation.find_by!(slug: org_slug)
    products = Product.where(organisation_id: org.id)

    # Find products without structured attributes
    with_attr_ids = products.joins(product_variants: :attribute_values).distinct.pluck(:id)
    no_attr_products = products.where.not(id: with_attr_ids).order(:name)

    puts "Found #{no_attr_products.count} products without structured attributes"

    # Load available attributes and values
    attributes = ProductAttribute.where(organisation_id: org.id).order(:position)
    attr_context = attributes.map do |attr|
      values = attr.product_attribute_values.order(:position).pluck(:value)
      { name: attr.name, slug: attr.slug, values: values }
    end

    # Build the reference list for the LLM prompt
    attr_reference = attr_context.map do |a|
      "#{a[:name]}: #{a[:values].join(", ")}"
    end.join("\n")

    chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")

    # Process in batches
    batch_size = 25
    results = []
    total = no_attr_products.count

    no_attr_products.each_slice(batch_size).with_index do |batch, batch_idx|
      offset = batch_idx * batch_size
      puts "Processing batch #{batch_idx + 1} (products #{offset + 1}-#{[offset + batch_size, total].min} of #{total})..."

      products_text = batch.map.with_index do |p, i|
        desc = p.description.to_s.gsub(/\s+/, " ").strip
        "#{i + 1}. [ID:#{p.id}] #{p.name} | #{desc}"
      end.join("\n")

      prompt = <<~PROMPT
        You are analyzing a product catalog for a Portuguese B2B e-commerce store that sells silver items, frames, albums, jewelry, and decorative pieces.

        For each product below, extract attribute values that match EXACTLY from the predefined lists. Only suggest values you are confident about based on the product name and description. Do NOT guess or infer values that aren't clearly indicated.

        AVAILABLE ATTRIBUTES AND THEIR VALID VALUES:
        #{attr_reference}

        IMPORTANT RULES:
        - For Tamanho (size): Look for "Dimensões:", "Dimensão:", "Altura:", or explicit measurements in the description. The value must match exactly one from the list (e.g., "10x15 cm", "Altura 22 cm", "Diâmetro 5 cm").
        - For Cor (color): Only if the color is explicitly part of the product identity (in the name), not the material. "Prata" as a material is NOT a color. "Azul", "Rosa" in the product name ARE colors.
        - For Modelo: Only if a specific model/shape variant is mentioned (e.g., "Oval", "Redondo", "Quadrado", "Vertical", "Horizontal").
        - For Acabamento: Only if explicitly mentioned (e.g., "acabamento mate", "acabamento brilho", "PVD").
        - For Tipo: Only if the product type matches (e.g., "Esferográfica", "Roller").
        - For NºFotos, Nºfotos, Espessura: Skip unless explicitly stated.
        - If no attributes can be confidently extracted, output NONE for that product.

        PRODUCTS:
        #{products_text}

        Respond in CSV format with NO header, one line per product:
        ID,Tamanho,Cor,Modelo,Acabamento,Tipo

        Use empty string for attributes you cannot determine. Use the EXACT value text from the lists above.
        Example: 123,10x15 cm,Azul,Vertical,,
        Example: 456,,Rosa,,,Esferográfica
        Example: 789,,,,,
      PROMPT

      response = chat.ask(prompt)

      # Parse the response
      response.content.strip.split("\n").each do |line|
        line = line.strip
        next if line.empty? || line.start_with?("ID,") || line.start_with?("```")

        parts = line.split(",", -1).map(&:strip)
        next if parts.length < 2

        product_id = parts[0].to_i
        product = batch.find { |p| p.id == product_id }
        next unless product

        results << {
          id: product.id,
          sku: product.sku,
          name: product.name,
          description: product.description.to_s.gsub(/\s+/, " ").truncate(200),
          tamanho: parts[1].to_s,
          cor: parts[2].to_s,
          modelo: parts[3].to_s,
          acabamento: parts[4].to_s,
          tipo: parts[5].to_s
        }
      end

      # Don't hammer the API
      sleep(1) if batch_idx < (total / batch_size)
    end

    # Write CSV
    CSV.open(output_csv, "w") do |csv|
      csv << %w[id sku name description tamanho cor modelo acabamento tipo]
      results.each do |r|
        csv << [r[:id], r[:sku], r[:name], r[:description], r[:tamanho], r[:cor], r[:modelo], r[:acabamento], r[:tipo]]
      end
    end

    filled = results.count { |r| [r[:tamanho], r[:cor], r[:modelo], r[:acabamento], r[:tipo]].any?(&:present?) }
    puts "\nDone! #{results.count} products exported to #{output_csv}"
    puts "#{filled} products have at least one suggested attribute"
    puts "#{results.count - filled} products have no suggestions"
    puts "\nReview the CSV, correct any errors, then run:"
    puts "  bin/rails 'attributes:import[#{output_csv},#{org_slug},dry_run]'"
  end

  desc "Import reviewed attribute CSV and create variant attribute associations"
  task :import, [:csv_path, :org_slug, :mode] => :environment do |_t, args|
    csv_path = args[:csv_path]
    org_slug = args[:org_slug] || "perestrelo-cunha"
    mode = args[:mode] || "dry_run"
    dry_run = mode == "dry_run"

    abort "Usage: bin/rails 'attributes:import[csv_path,org_slug,dry_run|execute]'" unless csv_path
    abort "CSV file not found: #{csv_path}" unless File.exist?(csv_path)

    org = Organisation.find_by!(slug: org_slug)
    attributes = ProductAttribute.where(organisation_id: org.id).index_by(&:slug)

    # Map attribute names to slugs
    attr_columns = {
      "tamanho" => "tamanho",
      "cor" => "cor",
      "modelo" => "modelo",
      "acabamento" => "acabamento",
      "tipo" => "tipo"
    }

    created = 0
    skipped = 0
    errors = []

    CSV.foreach(csv_path, headers: true) do |row|
      product_id = row["id"].to_i
      product = Product.find_by(id: product_id, organisation_id: org.id)

      unless product
        errors << "Product #{product_id} not found"
        next
      end

      variant = product.product_variants.first
      unless variant
        errors << "Product #{product_id} (#{product.name}) has no variant"
        next
      end

      # Check if variant already has attributes
      if variant.attribute_values.any?
        skipped += 1
        next
      end

      values_to_assign = []

      attr_columns.each do |col_name, attr_slug|
        value_text = row[col_name].to_s.strip
        next if value_text.blank?

        attribute = attributes[attr_slug]
        unless attribute
          errors << "Attribute #{attr_slug} not found for product #{product_id}"
          next
        end

        attr_value = attribute.product_attribute_values.find_by(value: value_text)
        unless attr_value
          errors << "Value '#{value_text}' not found for attribute #{attr_slug} (product #{product_id}: #{product.name})"
          next
        end

        values_to_assign << attr_value
      end

      next if values_to_assign.empty?

      if dry_run
        puts "[DRY RUN] Product #{product_id} (#{product.name}): would assign #{values_to_assign.map { |v| "#{v.product_attribute.name}=#{v.value}" }.join(", ")}"
      else
        ActiveRecord::Base.transaction do
          # Ensure product is linked to the attributes
          values_to_assign.each do |attr_value|
            attribute = attr_value.product_attribute

            # Link product to attribute if not already linked
            unless product.product_attributes.include?(attribute)
              product.product_product_attributes.create!(product_attribute: attribute)
            end

            # Link product to attribute value (available values)
            unless product.available_attribute_values.include?(attr_value)
              product.product_available_values.create!(product_attribute_value: attr_value)
            end

            # Link variant to attribute value
            unless variant.attribute_values.include?(attr_value)
              VariantAttributeValue.create!(product_variant: variant, product_attribute_value: attr_value)
            end
          end

          # Mark product as having variants if not already
          product.update!(has_variants: true) unless product.has_variants?
        end
        puts "Product #{product_id} (#{product.name}): assigned #{values_to_assign.map { |v| "#{v.product_attribute.name}=#{v.value}" }.join(", ")}"
      end

      created += 1
    end

    puts "\n=== Summary ==="
    puts "Mode: #{dry_run ? "DRY RUN" : "EXECUTE"}"
    puts "Products updated: #{created}"
    puts "Products skipped (already has attributes): #{skipped}"
    puts "Errors: #{errors.count}"
    errors.first(20).each { |e| puts "  - #{e}" }
    puts "  ... and #{errors.count - 20} more" if errors.count > 20
  end
end
