# frozen_string_literal: true

require "csv"

namespace :import do
  desc "Import product images from local files using a mapping CSV"
  task :local_images, [:mapping_csv, :images_folder, :org_slug, :mode] => :environment do |_t, args|
    mapping_csv   = args[:mapping_csv]
    images_folder = args[:images_folder]
    org_slug      = args[:org_slug]
    mode          = args[:mode] || "dry_run"

    unless mapping_csv && images_folder && org_slug
      puts "Usage: rails 'import:local_images[mapping.csv,/path/to/images/,org-slug,dry_run]'"
      puts "  mode: dry_run (default) or execute"
      exit 1
    end

    unless File.exist?(mapping_csv)
      puts "Error: Mapping CSV not found at #{mapping_csv}"
      exit 1
    end

    unless Dir.exist?(images_folder)
      puts "Error: Images folder not found at #{images_folder}"
      exit 1
    end

    organisation = Organisation.find_by(slug: org_slug)
    unless organisation
      puts "Error: Organisation '#{org_slug}' not found"
      exit 1
    end

    dry_run = mode != "execute"
    puts dry_run ? "=== DRY RUN MODE ===" : "=== EXECUTE MODE ==="
    puts "Organisation: #{organisation.name}"
    puts "-" * 60

    # Step 1: Build file index — scan images folder recursively
    puts "Scanning images folder..."
    file_index = {}
    image_extensions = %w[.jpg .jpeg .png .webp .gif .bmp .tiff]

    Dir.glob(File.join(images_folder, "**", "*")).each do |path|
      next unless File.file?(path)
      next unless image_extensions.include?(File.extname(path).downcase)

      basename = File.basename(path)
      key = basename.downcase
      # Keep first match if duplicates exist
      file_index[key] ||= path
    end
    puts "Found #{file_index.size} image files in folder"
    puts "-" * 60

    # Step 2: Parse mapping CSV — collect image filenames per REF
    puts "Parsing mapping CSV..."
    ref_images = {} # { ref => { type:, filenames: Set } }

    CSV.foreach(mapping_csv, headers: true, liberal_parsing: true) do |row|
      ref  = row["REF"]&.strip
      tipo = row["Tipo"]&.strip&.downcase
      next if ref.blank?

      filenames = Set.new

      # Column: "Imagem_sugerida (FOTOS SITE)"
      col1 = row["Imagem_sugerida (FOTOS SITE)"]&.strip
      if col1.present?
        col1.split(",").each { |f| filenames << f.strip if f.strip.present? }
      end

      # Column: "Imagens colocadas na Drive"
      col2 = row["Imagens colocadas na Drive"]&.strip
      if col2.present?
        col2.split(",").each { |f| filenames << f.strip if f.strip.present? }
      end

      next if filenames.empty?

      ref_images[ref] = { type: tipo, filenames: filenames }
    end
    puts "Found #{ref_images.size} REFs with image mappings"
    puts "-" * 60

    # Step 3: Process each REF
    success_count    = 0
    skipped_count    = 0
    not_found_count  = 0
    file_missing     = 0
    error_count      = 0
    already_attached = 0

    ref_images.each do |ref, data|
      type      = data[:type]
      filenames = data[:filenames]

      # Find product or variant by SKU
      product = organisation.products.find_by(sku: ref)
      variant = organisation.product_variants.find_by(sku: ref) unless product

      unless product || variant
        puts "NOT FOUND: [#{ref}] No product or variant with this SKU"
        not_found_count += 1
        next
      end

      if variant
        # Variant: has_one_attached :photo — use first available image
        if variant.photo.attached?
          puts "SKIP: [#{ref}] Variant already has photo"
          already_attached += 1
          next
        end

        # Find first available file
        attached = false
        filenames.each do |filename|
          file_path = file_index[filename.downcase]
          unless file_path
            puts "  FILE MISSING: [#{ref}] #{filename}"
            next
          end

          content_type = content_type_for(filename)

          if dry_run
            puts "DRY RUN: [#{ref}] Would attach #{filename} to variant"
          else
            begin
              variant.photo.attach(
                io: File.open(file_path),
                filename: filename,
                content_type: content_type
              )
              puts "SUCCESS: [#{ref}] Attached #{filename} to variant"
            rescue StandardError => e
              puts "ERROR: [#{ref}] #{e.class}: #{e.message}"
              error_count += 1
              next
            end
          end

          success_count += 1
          attached = true
          break
        end

        unless attached
          file_missing += 1
          puts "FILE MISSING: [#{ref}] No image files found for variant"
        end
      else
        # Product: has_many_attached :photos — attach all available images
        existing_filenames = product.photos.attached? ? product.photos.blobs.pluck(:filename).map(&:downcase) : []

        any_attached = false
        filenames.each do |filename|
          if existing_filenames.include?(filename.downcase)
            puts "SKIP: [#{ref}] #{filename} already attached"
            already_attached += 1
            next
          end

          file_path = file_index[filename.downcase]
          unless file_path
            puts "  FILE MISSING: [#{ref}] #{filename}"
            file_missing += 1
            next
          end

          content_type = content_type_for(filename)

          if dry_run
            puts "DRY RUN: [#{ref}] Would attach #{filename} to product #{product.name}"
          else
            begin
              product.photos.attach(
                io: File.open(file_path),
                filename: filename,
                content_type: content_type
              )
              puts "SUCCESS: [#{ref}] Attached #{filename} to #{product.name}"
            rescue StandardError => e
              puts "ERROR: [#{ref}] #{e.class}: #{e.message}"
              error_count += 1
              next
            end
          end

          success_count += 1
          any_attached = true
        end

        if !any_attached && existing_filenames.empty?
          skipped_count += 1
        end
      end
    end

    # Summary
    puts "-" * 60
    puts dry_run ? "DRY RUN COMPLETE" : "IMPORT COMPLETE"
    puts "  Attached:         #{success_count}"
    puts "  Already attached: #{already_attached}"
    puts "  Skipped:          #{skipped_count}"
    puts "  SKU not found:    #{not_found_count}"
    puts "  File missing:     #{file_missing}"
    puts "  Errors:           #{error_count}"
    puts "  Total REFs:       #{ref_images.size}"
  end
end

def content_type_for(filename)
  ext = File.extname(filename).downcase
  case ext
  when ".jpg", ".jpeg" then "image/jpeg"
  when ".png"          then "image/png"
  when ".webp"         then "image/webp"
  when ".gif"          then "image/gif"
  when ".bmp"          then "image/bmp"
  when ".tiff"         then "image/tiff"
  else "application/octet-stream"
  end
end
