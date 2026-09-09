require "csv"

namespace :attributes do
  desc "Extract attribute suggestions using pattern matching (no LLM), output CSV for review"
  task :extract_local, [:org_slug, :output_csv] => :environment do |_t, args|
    org_slug = args[:org_slug] || "perestrelo-cunha"
    output_csv = args[:output_csv] || "products_attributes_review.csv"

    org = Organisation.find_by!(slug: org_slug)
    products = Product.where(organisation_id: org.id)

    with_attr_ids = products.joins(product_variants: :attribute_values).distinct.pluck(:id)
    no_attr_products = products.where.not(id: with_attr_ids).order(:name)

    puts "Found #{no_attr_products.count} products without structured attributes"

    # Load attribute values indexed by attribute slug
    attributes = ProductAttribute.where(organisation_id: org.id).index_by(&:slug)
    tamanho_values = attributes["tamanho"]&.product_attribute_values&.pluck(:value) || []
    cor_values = attributes["cor"]&.product_attribute_values&.pluck(:value) || []
    modelo_values = attributes["modelo"]&.product_attribute_values&.pluck(:value) || []
    acabamento_values = attributes["acabamento"]&.product_attribute_values&.pluck(:value) || []
    tipo_values = attributes["tipo"]&.product_attribute_values&.pluck(:value) || []

    # Normalize Portuguese decimals: "4,5" → "4.5"
    def normalize_dim(text)
      text.gsub(/(\d),(\d)/, '\1.\2').strip
    end

    # Build a lookup set for tamanho (normalized)
    tamanho_lookup = {}
    tamanho_values.each { |v| tamanho_lookup[v.downcase.strip] = v }

    results = []

    no_attr_products.find_each do |product|
      name = product.name.to_s
      desc = product.description.to_s.gsub(/\s+/, " ").strip
      full_text = "#{name} #{desc}"

      tamanho = nil
      cor = nil
      modelo = nil
      acabamento = nil
      tipo = nil

      # === TAMANHO ===
      # Extract from description patterns like "Dimensões: 20x25 cm", "Dimensão: 24 cm", "Altura: 30 cm"
      dim_match = desc.match(/Dimens(?:ões|ão)\s*(?:exteriores)?\s*:\s*([\d,\.x×X]+\s*cm)/i) ||
                  desc.match(/Altura\s*:\s*([\d,\.]+\s*cm)/i) ||
                  desc.match(/Diâmetro\s*:\s*([\d,\.]+\s*cm)/i)

      if dim_match
        extracted = normalize_dim(dim_match[1])

        # Try to match "Altura X cm" format if it came from "Altura:" pattern
        if desc =~ /Altura\s*:/i
          candidate = "Altura #{extracted}"
          if tamanho_lookup[candidate.downcase]
            tamanho = tamanho_lookup[candidate.downcase]
          end
        end

        # Try to match "Diâmetro X cm" format
        if desc =~ /Diâmetro\s*:/i && tamanho.nil?
          candidate = "Diâmetro #{extracted}"
          if tamanho_lookup[candidate.downcase]
            tamanho = tamanho_lookup[candidate.downcase]
          end
        end

        # Try direct match
        if tamanho.nil? && tamanho_lookup[extracted.downcase]
          tamanho = tamanho_lookup[extracted.downcase]
        end
      end

      # === COR ===
      # Only match colors explicitly in the product NAME or explicitly stated as "cor X" in description
      # Exclude "Prata" as it's usually material, not color
      color_candidates = cor_values - ["Prata", "Normal"]

      # Check for "cor X" pattern in description
      cor_in_desc = desc.match(/cor\s+(#{color_candidates.map { |c| Regexp.escape(c) }.join("|")})/i)
      if cor_in_desc
        matched = color_candidates.find { |c| c.downcase == cor_in_desc[1].downcase }
        cor = matched if matched
      end

      # Check for color as last word(s) in product name (e.g., "Medalha de Berço Azul", "Álbum Fotos Sapo Rosa")
      if cor.nil?
        color_candidates.each do |color|
          # Match at end of name or as a standalone word surrounded by spaces
          if name =~ /\b#{Regexp.escape(color)}\b\s*$/i
            cor = color
            break
          end
        end
      end

      # === TIPO ===
      tipo_candidates = tipo_values
      tipo_candidates.each do |t|
        if name =~ /\b#{Regexp.escape(t)}\b/i && t.length > 3
          tipo = t
          break
        end
      end

      # === ACABAMENTO ===
      if desc =~ /acabamento\s+(mate|brilho)/i
        matched_ac = acabamento_values.find { |a| a.downcase == $1.downcase }
        acabamento = matched_ac if matched_ac
      end

      # === MODELO ===
      # Only match very specific model names in the product name
      # Avoid short/ambiguous ones like "1", "2", "3", etc.
      modelo_safe = modelo_values.select { |m| m.length > 3 }
      modelo_safe.each do |m|
        if name =~ /\b#{Regexp.escape(m)}\b/i
          modelo = m
          break
        end
      end

      results << {
        id: product.id,
        sku: product.sku,
        name: name,
        description: desc.truncate(200),
        tamanho: tamanho.to_s,
        cor: cor.to_s,
        modelo: modelo.to_s,
        acabamento: acabamento.to_s,
        tipo: tipo.to_s
      }
    end

    CSV.open(output_csv, "w") do |csv|
      csv << %w[id sku name description tamanho cor modelo acabamento tipo]
      results.each do |r|
        csv << [r[:id], r[:sku], r[:name], r[:description], r[:tamanho], r[:cor], r[:modelo], r[:acabamento], r[:tipo]]
      end
    end

    filled = results.count { |r| [r[:tamanho], r[:cor], r[:modelo], r[:acabamento], r[:tipo]].any?(&:present?) }
    with_tamanho = results.count { |r| r[:tamanho].present? }
    with_cor = results.count { |r| r[:cor].present? }
    with_modelo = results.count { |r| r[:modelo].present? }
    with_tipo = results.count { |r| r[:tipo].present? }
    with_acabamento = results.count { |r| r[:acabamento].present? }

    puts "\nDone! #{results.count} products exported to #{output_csv}"
    puts "#{filled} products have at least one suggested attribute"
    puts "  Tamanho: #{with_tamanho}"
    puts "  Cor: #{with_cor}"
    puts "  Modelo: #{with_modelo}"
    puts "  Acabamento: #{with_acabamento}"
    puts "  Tipo: #{with_tipo}"
    puts "#{results.count - filled} products have no suggestions"
    puts "\nReview the CSV, correct any errors, then run:"
    puts "  bin/rails 'attributes:import[#{output_csv},#{org_slug},dry_run]'"
  end
end
