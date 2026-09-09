namespace :cleanup do
  desc "Deduplicate Product/ProductVariant photo blobs by checksum. " \
       "Modes: dry_run (default) or execute. Idempotent — safe to re-run."
  task :photo_duplicates, [:org_slug, :mode] => :environment do |_, args|
    org_slug = args[:org_slug]
    mode = (args[:mode].presence || "dry_run").to_s

    if org_slug.blank? || !%w[dry_run execute].include?(mode)
      abort("Usage: rake 'cleanup:photo_duplicates[org_slug,dry_run|execute]'")
    end

    org = Organisation.find_by!(slug: org_slug)
    human = ->(b) { ActiveSupport::NumberHelper.number_to_human_size(b || 0) }

    puts "=" * 78
    puts "Photo duplicates cleanup — #{org.name} (#{org.slug})"
    puts "Mode: #{mode.upcase}"
    puts "=" * 78

    product_ids = org.products.pluck(:id)
    variant_ids = org.product_variants.pluck(:id)
    puts "Scoped to #{product_ids.size} products + #{variant_ids.size} variants"

    org_attachments_scope = ActiveStorage::Attachment
      .where(record_type: "Product", record_id: product_ids, name: "photos")
      .or(
        ActiveStorage::Attachment
          .where(record_type: "ProductVariant", record_id: variant_ids, name: "photo")
      )
    org_blob_ids = org_attachments_scope.pluck(:blob_id).uniq

    # -------------------------------------------------------------------------
    # PASS 1 — For each duplicate-checksum group, walk every attachment
    # pointing to a non-canonical blob and either repoint it (safe) or destroy
    # it (would collide with an existing attachment to the canonical blob on
    # the same record). Combines what was originally split into Pass A + B.
    # -------------------------------------------------------------------------
    puts ""
    puts "PASS 1 — Smart repoint / destroy per attachment (collision-aware)"
    puts "-" * 78

    checksum_groups = ActiveStorage::Blob
      .where(id: org_blob_ids)
      .group(:checksum)
      .pluck(Arel.sql("checksum"), Arel.sql("ARRAY_AGG(id ORDER BY id)"))

    repointed = 0
    destroyed = 0
    blobs_orphaned = Set.new
    bytes_to_free = 0

    checksum_groups.each do |_checksum, blob_ids|
      next if blob_ids.size < 2

      canonical_id, *other_ids = blob_ids
      sample_size = ActiveStorage::Blob.where(id: other_ids.first).pick(:byte_size).to_i

      ActiveStorage::Attachment.where(blob_id: other_ids).find_each do |att|
        already_has_canonical = ActiveStorage::Attachment.exists?(
          record_type: att.record_type,
          record_id: att.record_id,
          name: att.name,
          blob_id: canonical_id
        )

        if already_has_canonical
          destroyed += 1
          att.destroy if mode == "execute"
        else
          repointed += 1
          att.update_column(:blob_id, canonical_id) if mode == "execute"
        end

        blobs_orphaned << att.blob_id
        bytes_to_free += sample_size if blobs_orphaned.size > 0 && blobs_orphaned.include?(att.blob_id)
      end
    end

    # bytes_to_free over-counted in the loop above (per attachment, not per blob)
    # Recompute correctly: 1 bytes_per_blob × number of orphaned blobs.
    bytes_to_free = ActiveStorage::Blob.where(id: blobs_orphaned.to_a).sum(:byte_size)

    puts "  Attachments repointed to canonical: #{repointed}"
    puts "  Attachments destroyed (collisions): #{destroyed}"
    puts "  Distinct blobs to be orphaned     : #{blobs_orphaned.size}"
    puts "  Estimated bytes to free           : #{human[bytes_to_free]}"

    # -------------------------------------------------------------------------
    # PASS 2 — Purge unattached blobs (cascades to Cloudinary destroy).
    # In execute mode: blobs orphaned by Pass 1 + any pre-existing unattached
    # blobs in this org. In dry_run: project from Pass 1's set.
    # -------------------------------------------------------------------------
    puts ""
    puts "PASS 2 — Purge unattached blobs (deletes from Cloudinary)"
    puts "-" * 78

    if mode == "execute"
      unattached = ActiveStorage::Blob.unattached.where(id: org_blob_ids + blobs_orphaned.to_a)
      pass2_count = unattached.count
      pass2_bytes = unattached.sum(:byte_size)
      unattached.find_each(&:purge_later)
      puts "  Blobs enqueued for purge: #{pass2_count}"
      puts "  Bytes to free            : #{human[pass2_bytes]}"
      puts "  (purge runs async via Solid Queue → Cloudinary::Uploader.destroy)"
    else
      puts "  Projected blobs to purge: #{blobs_orphaned.size}"
      puts "  Projected bytes freed   : #{human[bytes_to_free]}"
      puts "  (would enqueue ActiveStorage::PurgeJob for each → Cloudinary destroy)"
    end

    puts ""
    puts "=" * 78
    if mode == "dry_run"
      puts "DRY RUN — no changes made. Re-run with [#{org_slug},execute] to apply."
    else
      puts "EXECUTED — purges enqueued in Solid Queue. Watch logs for completion."
    end
    puts "=" * 78
  end
end
