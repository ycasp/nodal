require "csv"

namespace :audit do
  desc "Read-only report on duplicate product/variant photo blobs. No changes made."
  task :photo_duplicates, [:org_slug, :csv_path] => :environment do |_, args|
    org_slug = args[:org_slug]
    if org_slug.blank?
      abort("Usage: rake 'audit:photo_duplicates[org_slug]' or 'audit:photo_duplicates[org_slug,output.csv]'")
    end

    csv_path = args[:csv_path].presence || "photo_duplicates_audit.csv"
    org = Organisation.find_by!(slug: org_slug)

    human = ->(bytes) { ActiveSupport::NumberHelper.number_to_human_size(bytes || 0) }
    pct = ->(num, denom) { denom.to_i.zero? ? "0.0" : (num * 100.0 / denom).round(1).to_s }

    puts "=" * 78
    puts "Photo duplicates audit — #{org.name} (#{org.slug})"
    puts "Read-only — no changes will be made"
    puts "=" * 78

    product_ids = org.products.pluck(:id)
    variant_ids = org.product_variants.pluck(:id)
    puts "Products: #{product_ids.size}, Variants: #{variant_ids.size}"

    csv_rows = []

    # -------------------------------------------------------------------------
    # 1. GLOBAL SUMMARY
    # -------------------------------------------------------------------------
    photo_attachments = ActiveStorage::Attachment
      .where(record_type: "Product", record_id: product_ids, name: "photos")
      .or(
        ActiveStorage::Attachment
          .where(record_type: "ProductVariant", record_id: variant_ids, name: "photo")
      )

    blob_ids = photo_attachments.pluck(:blob_id).uniq
    blobs = ActiveStorage::Blob.where(id: blob_ids)

    total_attachments = photo_attachments.count
    total_blobs = blob_ids.size
    total_bytes = blobs.sum(:byte_size)

    checksum_groups = blobs.group(:checksum).pluck(
      Arel.sql("checksum"),
      Arel.sql("COUNT(*)"),
      Arel.sql("MAX(byte_size)")
    )
    duplicate_groups = checksum_groups.select { |_, count, _| count > 1 }
    wasted_bytes = duplicate_groups.sum { |_, count, size| (count - 1) * size }
    duplicate_blobs = duplicate_groups.sum { |_, count, _| count - 1 }

    puts ""
    puts "1. GLOBAL SUMMARY"
    puts "-" * 78
    puts "  Total photo attachments  : #{total_attachments}"
    puts "  Unique blob records      : #{total_blobs}"
    puts "  Unique checksums         : #{checksum_groups.size}"
    puts "  Duplicate blob records   : #{duplicate_blobs}"
    puts "  Total stored bytes       : #{human[total_bytes]}"
    puts "  Wasted bytes (estimate)  : #{human[wasted_bytes]}"
    puts "  Waste %                  : #{pct[wasted_bytes, total_bytes]}%"

    # -------------------------------------------------------------------------
    # 2. DUPLICATES WITHIN SAME PRODUCT
    # -------------------------------------------------------------------------
    puts ""
    puts "2. DUPLICATES WITHIN SAME PRODUCT (same content attached 2+ times)"
    puts "-" * 78

    intra_dups = ActiveStorage::Attachment
      .joins("JOIN active_storage_blobs blobs ON blobs.id = active_storage_attachments.blob_id")
      .where(record_type: "Product", record_id: product_ids, name: "photos")
      .group("active_storage_attachments.record_id", "blobs.checksum")
      .having("COUNT(*) > 1")
      .pluck(
        "active_storage_attachments.record_id",
        "blobs.checksum",
        Arel.sql("COUNT(*)"),
        Arel.sql("MAX(blobs.byte_size)")
      )

    if intra_dups.empty?
      puts "  None found"
    else
      affected_pids = intra_dups.map(&:first).uniq
      products_by_id = Product.where(id: affected_pids).index_by(&:id)
      total_waste = intra_dups.sum { |_, _, c, s| (c - 1) * s }

      puts "  #{intra_dups.size} duplicate groups across #{affected_pids.size} products"
      puts "  Wasted bytes: #{human[total_waste]}"
      puts ""
      puts format("  %-15s %-35s %5s %12s", "SKU", "Name", "Dups", "Wasted")

      intra_dups.sort_by { |_, _, c, s| -((c - 1) * s) }.first(20).each do |pid, checksum, count, size|
        prod = products_by_id[pid]
        puts format("  %-15s %-35s %5d %12s",
                    (prod&.sku || pid).to_s[0, 15],
                    prod&.name.to_s[0, 35],
                    count,
                    human[(count - 1) * size])
      end
      puts "  ... +#{intra_dups.size - 20} more (see CSV)" if intra_dups.size > 20

      intra_dups.each do |pid, checksum, count, size|
        prod = products_by_id[pid]
        csv_rows << {
          type: "intra_product",
          product_id: pid,
          product_sku: prod&.sku,
          product_name: prod&.name,
          variant_id: nil,
          variant_sku: nil,
          checksum: checksum,
          dup_count: count,
          wasted_bytes: (count - 1) * size
        }
      end
    end

    # -------------------------------------------------------------------------
    # 3. PRODUCT + VARIANT OVERLAP (same photo attached to product AND its variant)
    # -------------------------------------------------------------------------
    puts ""
    puts "3. SAME PHOTO ATTACHED TO PRODUCT AND ITS VARIANT"
    puts "-" * 78

    overlap_sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, product_ids])
      SELECT
        p_att.record_id AS product_id,
        v_att.record_id AS variant_id,
        p_blobs.checksum AS checksum,
        p_blobs.byte_size AS byte_size
      FROM active_storage_attachments p_att
      JOIN active_storage_blobs p_blobs ON p_blobs.id = p_att.blob_id
      JOIN product_variants pv ON pv.product_id = p_att.record_id
      JOIN active_storage_attachments v_att
        ON v_att.record_id = pv.id
       AND v_att.record_type = 'ProductVariant'
       AND v_att.name = 'photo'
      JOIN active_storage_blobs v_blobs
        ON v_blobs.id = v_att.blob_id
       AND v_blobs.checksum = p_blobs.checksum
      WHERE p_att.record_type = 'Product'
        AND p_att.name = 'photos'
        AND p_att.record_id IN (?)
    SQL
    overlap_rows = ActiveRecord::Base.connection.select_all(overlap_sql).to_a

    if overlap_rows.empty?
      puts "  None found"
    else
      total_waste = overlap_rows.sum { |r| r["byte_size"].to_i }
      pids = overlap_rows.map { |r| r["product_id"] }.uniq
      vids = overlap_rows.map { |r| r["variant_id"] }.uniq
      products_by_id = Product.where(id: pids).index_by(&:id)
      variants_by_id = ProductVariant.where(id: vids).index_by(&:id)

      puts "  #{overlap_rows.size} overlapping (product, variant) pairs"
      puts "  Wasted bytes: #{human[total_waste]}"
      puts ""
      puts format("  %-15s %-30s %-15s %12s", "Product SKU", "Product Name", "Variant SKU", "Wasted")

      overlap_rows.first(20).each do |r|
        prod = products_by_id[r["product_id"]]
        var = variants_by_id[r["variant_id"]]
        puts format("  %-15s %-30s %-15s %12s",
                    (prod&.sku || r["product_id"]).to_s[0, 15],
                    prod&.name.to_s[0, 30],
                    (var&.sku || r["variant_id"]).to_s[0, 15],
                    human[r["byte_size"].to_i])
      end
      puts "  ... +#{overlap_rows.size - 20} more (see CSV)" if overlap_rows.size > 20

      overlap_rows.each do |r|
        prod = products_by_id[r["product_id"]]
        var = variants_by_id[r["variant_id"]]
        csv_rows << {
          type: "product_variant_overlap",
          product_id: r["product_id"],
          product_sku: prod&.sku,
          product_name: prod&.name,
          variant_id: r["variant_id"],
          variant_sku: var&.sku,
          checksum: r["checksum"],
          dup_count: 2,
          wasted_bytes: r["byte_size"].to_i
        }
      end
    end

    # -------------------------------------------------------------------------
    # 4. SAME CHECKSUM ACROSS MULTIPLE PRODUCTS (>5)
    # -------------------------------------------------------------------------
    puts ""
    puts "4. SAME PHOTO ACROSS MULTIPLE PRODUCTS (>5 — could be legitimate or accidental)"
    puts "-" * 78

    cross = ActiveStorage::Attachment
      .joins("JOIN active_storage_blobs blobs ON blobs.id = active_storage_attachments.blob_id")
      .where(record_type: "Product", record_id: product_ids, name: "photos")
      .group("blobs.checksum")
      .having("COUNT(DISTINCT active_storage_attachments.record_id) > 5")
      .pluck(
        "blobs.checksum",
        Arel.sql("COUNT(DISTINCT active_storage_attachments.record_id)"),
        Arel.sql("MAX(blobs.byte_size)")
      )

    if cross.empty?
      puts "  None found (no checksum is shared by more than 5 products)"
    else
      puts "  #{cross.size} checksums shared by 6+ products each"
      puts ""
      puts format("  %-25s %10s %12s", "Checksum", "Products", "Per-blob")
      cross.sort_by { |_, c, _| -c }.first(20).each do |checksum, count, size|
        puts format("  %-25s %10d %12s",
                    checksum.to_s[0, 25],
                    count,
                    human[size])
      end
      puts "  ... +#{cross.size - 20} more (see CSV)" if cross.size > 20

      cross.each do |checksum, count, size|
        csv_rows << {
          type: "cross_product",
          product_id: nil,
          product_sku: nil,
          product_name: nil,
          variant_id: nil,
          variant_sku: nil,
          checksum: checksum,
          dup_count: count,
          wasted_bytes: (count - 1) * size
        }
      end
    end

    # -------------------------------------------------------------------------
    # CSV OUTPUT
    # -------------------------------------------------------------------------
    CSV.open(csv_path, "w") do |csv|
      csv << %w[type product_id product_sku product_name variant_id variant_sku checksum dup_count wasted_bytes]
      csv_rows.each do |r|
        csv << [r[:type], r[:product_id], r[:product_sku], r[:product_name],
                r[:variant_id], r[:variant_sku], r[:checksum], r[:dup_count], r[:wasted_bytes]]
      end
    end

    puts ""
    puts "=" * 78
    puts "CSV written to: #{csv_path} (#{csv_rows.size} rows)"
    puts "=" * 78
  end
end
