# frozen_string_literal: true

require "csv"

namespace :import do
  desc "Import customer billing addresses from CSV. Matches customers by external_id scoped to organisation."
  task :billing_addresses, [:csv_path, :org_slug, :mode] => :environment do |_t, args|
    csv_path = args[:csv_path]
    org_slug = args[:org_slug]
    mode = args[:mode] || "dry_run"

    unless csv_path && org_slug
      puts "Usage:"
      puts "  rails 'import:billing_addresses[path/to/file.csv,org-slug,dry_run]'"
      puts "  rails 'import:billing_addresses[path/to/file.csv,org-slug,execute]'"
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
    puts dry_run ? "IMPORT BILLING ADDRESSES (DRY RUN)" : "IMPORT BILLING ADDRESSES (EXECUTE)"
    puts "Organisation: #{org.name} (#{org.slug})"
    puts "CSV: #{csv_path}"
    puts "=" * 70

    rows = CSV.read(csv_path, headers: true, liberal_parsing: true)
    puts "\nRows in CSV: #{rows.size}\n"

    created = []
    updated = []
    unchanged = []
    missing_customer = []
    skipped_blank_street = []
    postal_normalizations = []
    errors = []

    rows.each_with_index do |row, idx|
      external_id = row["External_ID"].to_s.strip
      street_name = row["Rua"].to_s.strip
      street_nr = row["Nº"].to_s.strip
      postal_code_raw = row["Codigo postal"].to_s.strip
      city = row["Cidade"].to_s.strip
      country = row["País"].to_s.strip

      if external_id.empty?
        errors << "Row #{idx + 2}: blank External_ID"
        next
      end

      if street_name.empty?
        skipped_blank_street << { external_id: external_id, nome: row["Nome"] }
        next
      end

      postal_code = normalize_postal_code(postal_code_raw)
      postal_normalizations << { external_id: external_id, from: postal_code_raw, to: postal_code } if postal_code != postal_code_raw

      city = "N/D" if city.empty?
      country = "Portugal" if country.empty?

      customers = org.customers.where(external_id: external_id).to_a
      if customers.empty?
        missing_customer << { external_id: external_id, nome: row["Nome"] }
        next
      end

      if customers.size > 1
        errors << "External_ID #{external_id}: #{customers.size} customers match (sources: #{customers.map(&:external_source).uniq.inspect}) — skipping"
        next
      end

      customer = customers.first

      attrs = {
        street_name: street_name,
        street_nr: street_nr.presence,
        postal_code: postal_code,
        city: city,
        country: country,
        address_type: "billing",
        active: true
      }

      existing = customer.billing_address_with_archived

      if existing
        old_attrs = existing.slice(:street_name, :street_nr, :postal_code, :city, :country, :active).symbolize_keys
        new_attrs_for_diff = attrs.slice(:street_name, :street_nr, :postal_code, :city, :country, :active)

        if old_attrs == new_attrs_for_diff
          unchanged << { external_id: external_id, nome: row["Nome"] }
        else
          if dry_run
            updated << { external_id: external_id, nome: row["Nome"], from: old_attrs, to: new_attrs_for_diff }
          else
            begin
              existing.update!(attrs)
              updated << { external_id: external_id, nome: row["Nome"], from: old_attrs, to: new_attrs_for_diff }
            rescue ActiveRecord::RecordInvalid => e
              errors << "External_ID #{external_id} (update): #{e.message}"
            end
          end
        end
      else
        if dry_run
          created << { external_id: external_id, nome: row["Nome"], attrs: attrs }
        else
          begin
            customer.create_billing_address_with_archived!(attrs)
            created << { external_id: external_id, nome: row["Nome"], attrs: attrs }
          rescue ActiveRecord::RecordInvalid => e
            errors << "External_ID #{external_id} (create): #{e.message}"
          end
        end
      end
    end

    puts "\n" + ("=" * 70)
    puts "REPORT"
    puts "=" * 70
    puts "Created:           #{created.size}"
    puts "Updated:           #{updated.size}"
    puts "Unchanged:         #{unchanged.size}"
    puts "Missing customer:  #{missing_customer.size}"
    puts "Skipped (no Rua):  #{skipped_blank_street.size}"
    puts "Postal normalized: #{postal_normalizations.size}"
    puts "Errors:            #{errors.size}"

    if missing_customer.any?
      puts "\n--- Missing customers (External_IDs not found in org) ---"
      missing_customer.first(50).each { |m| puts "  #{m[:external_id].to_s.rjust(6)}  #{m[:nome]}" }
      puts "  ... and #{missing_customer.size - 50} more" if missing_customer.size > 50
    end

    if skipped_blank_street.any?
      puts "\n--- Skipped (blank Rua) ---"
      skipped_blank_street.each { |m| puts "  #{m[:external_id].to_s.rjust(6)}  #{m[:nome]}" }
    end

    if postal_normalizations.any?
      puts "\n--- Postal code normalizations (first 30) ---"
      postal_normalizations.first(30).each { |n| puts "  #{n[:external_id].to_s.rjust(6)}  #{n[:from].inspect} -> #{n[:to].inspect}" }
      puts "  ... and #{postal_normalizations.size - 30} more" if postal_normalizations.size > 30
    end

    if updated.any?
      puts "\n--- Updates (first 10 diffs) ---"
      updated.first(10).each do |u|
        puts "  #{u[:external_id]}  #{u[:nome]}"
        u[:from].each do |k, old_v|
          new_v = u[:to][k]
          puts "    #{k}: #{old_v.inspect} -> #{new_v.inspect}" if old_v != new_v
        end
      end
      puts "  ... and #{updated.size - 10} more" if updated.size > 10
    end

    if errors.any?
      puts "\n--- Errors ---"
      errors.first(30).each { |e| puts "  #{e}" }
      puts "  ... and #{errors.size - 30} more" if errors.size > 30
    end

    puts "\n" + ("=" * 70)
    puts dry_run ? "DRY RUN COMPLETE — nothing written" : "EXECUTE COMPLETE"
    puts "=" * 70
  end

  def normalize_postal_code(raw)
    return raw if raw.nil? || raw.empty?
    s = raw.strip.gsub(/\s+/, "")
    s = s.gsub(%r{[/]+}, "-").gsub(/-+/, "-")
    s = s.sub(/-\z/, "")
    s
  end

  desc "For customers with a billing address and no active shipping address, copy billing to shipping."
  task :copy_billing_to_shipping, [:org_slug, :mode] => :environment do |_t, args|
    org_slug = args[:org_slug]
    mode = args[:mode] || "dry_run"

    unless org_slug
      puts "Usage:"
      puts "  rails 'import:copy_billing_to_shipping[org-slug,dry_run]'"
      puts "  rails 'import:copy_billing_to_shipping[org-slug,execute]'"
      exit 1
    end

    org = Organisation.find_by(slug: org_slug)
    unless org
      puts "Error: Organisation '#{org_slug}' not found"
      exit 1
    end

    dry_run = mode == "dry_run"

    puts "=" * 70
    puts dry_run ? "COPY BILLING -> SHIPPING (DRY RUN)" : "COPY BILLING -> SHIPPING (EXECUTE)"
    puts "Organisation: #{org.name} (#{org.slug})"
    puts "=" * 70

    customers = org.customers
      .includes(:billing_address, :shipping_addresses)
      .where(id: Address.billing.active.where(addressable_type: "Customer").select(:addressable_id))

    puts "\nCustomers with active billing address: #{customers.size}"

    created = []
    already_has_shipping = 0
    errors = []

    customers.find_each do |customer|
      billing = customer.billing_address
      next unless billing

      if customer.shipping_addresses.any?
        already_has_shipping += 1
        next
      end

      attrs = {
        street_name: billing.street_name,
        street_nr: billing.street_nr,
        postal_code: billing.postal_code,
        city: billing.city,
        country: billing.country,
        address_type: "shipping",
        active: true,
        addressable: customer
      }

      if dry_run
        created << { external_id: customer.external_id, nome: customer.company_name, attrs: attrs }
      else
        begin
          Address.create!(attrs)
          created << { external_id: customer.external_id, nome: customer.company_name, attrs: attrs }
        rescue ActiveRecord::RecordInvalid => e
          errors << "Customer ##{customer.id} (#{customer.company_name}): #{e.message}"
        end
      end
    end

    puts "\n" + ("=" * 70)
    puts "REPORT"
    puts "=" * 70
    puts "Shipping addresses to create: #{created.size}"
    puts "Already had shipping:         #{already_has_shipping}"
    puts "Errors:                       #{errors.size}"

    if created.any?
      puts "\n--- Sample (first 10) ---"
      created.first(10).each do |c|
        puts "  #{c[:external_id].to_s.rjust(6)}  #{c[:nome]}"
        puts "      #{c[:attrs][:street_name]} #{c[:attrs][:street_nr]} | #{c[:attrs][:postal_code]} #{c[:attrs][:city]} | #{c[:attrs][:country]}"
      end
    end

    if errors.any?
      puts "\n--- Errors ---"
      errors.first(30).each { |e| puts "  #{e}" }
      puts "  ... and #{errors.size - 30} more" if errors.size > 30
    end

    puts "\n" + ("=" * 70)
    puts dry_run ? "DRY RUN COMPLETE — nothing written" : "EXECUTE COMPLETE"
    puts "=" * 70
  end
end
