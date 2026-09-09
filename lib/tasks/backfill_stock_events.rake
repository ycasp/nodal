# frozen_string_literal: true

# Reconstructs StockEvent rows from the diffs the ERP sync has already been
# writing into erp_sync_logs.change_details.
#
# The sync records `variant.changes` per row, so a log entry literally carries
# {"stock_quantity" => [5, 0]} with a timestamp. That is exactly the transition
# StockEvent stores, which means the event log can start with months of real
# history instead of waiting for new syncs to accumulate it.
#
# Re-runnable: execute mode wipes the org's source="erp_sync_log" events first,
# so it never double-counts. Events recorded live by StockRulesService
# (source="app") are never touched.
namespace :stock do
  desc "Backfill StockEvents from historical ERP sync logs"
  task :backfill_events, [ :org_slug, :mode ] => :environment do |_t, args|
    org_slug = args[:org_slug]
    mode     = args[:mode] || "dry_run"

    unless org_slug
      puts "Usage: rails 'stock:backfill_events[org-slug,dry_run]'"
      puts "  mode: dry_run (default) or execute"
      exit 1
    end

    organisation = Organisation.find_by(slug: org_slug)
    unless organisation
      puts "Error: Organisation '#{org_slug}' not found"
      exit 1
    end

    execute   = mode == "execute"
    threshold = organisation.low_stock_threshold

    puts "Organisation : #{organisation.name} (#{organisation.slug})"
    puts "Mode         : #{execute ? 'EXECUTE' : 'DRY RUN'}"
    puts "Low threshold: #{threshold}"
    puts "-" * 70

    # external_id -> variant id. change_details keys rows by external_id, not by
    # variant id, so the mapping has to be rebuilt here.
    variant_ids = ProductVariant.where(organisation_id: organisation.id)
                                .where.not(external_id: [ nil, "" ])
                                .pluck(:external_id, :id)
                                .to_h
    puts "Variants with external_id: #{variant_ids.size}"

    logs = organisation.erp_sync_logs
                       .for_entity("products")
                       .where.not(change_details: nil)
                       .order(:created_at)

    puts "Product sync logs to scan : #{logs.count}"
    puts

    rows          = []
    unresolved    = Hash.new(0)
    skipped_shape = 0

    logs.find_each do |log|
      Array(log.change_details).each do |entry|
        next unless entry["record_type"] == "ProductVariant"

        change = entry.dig("changes", "stock_quantity")
        # 'created' entries carry a {name:, sku:} payload, not a [from, to] pair.
        next if change.blank?
        unless change.is_a?(Array) && change.size == 2
          skipped_shape += 1
          next
        end

        external_id = entry["external_id"]
        variant_id  = variant_ids[external_id]
        if variant_id.nil?
          unresolved[external_id] += 1
          next
        end

        from, to = change
        kind = StockEvent.kind_for(from: from, to: to, low_stock_threshold: threshold)
        next if kind.nil?

        occurred_at = begin
          Time.zone.parse(entry["at"].to_s) || log.created_at
        rescue ArgumentError, TypeError
          log.created_at
        end

        rows << {
          organisation_id: organisation.id,
          product_variant_id: variant_id,
          kind: kind,
          from_quantity: from.to_i,
          to_quantity: to.to_i,
          occurred_at: occurred_at,
          source: "erp_sync_log",
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end

    by_kind = rows.group_by { |r| r[:kind] }.transform_values(&:size)
    puts "Events reconstructed: #{rows.size}"
    StockEvent::KINDS.each { |k| puts "  #{k.ljust(15)} #{by_kind[k] || 0}" }
    puts
    puts "Skipped — external_id not matching any variant: #{unresolved.values.sum} (#{unresolved.size} distinct)"
    puts "Skipped — unexpected change shape            : #{skipped_shape}"

    if rows.any?
      span = rows.map { |r| r[:occurred_at] }.minmax
      puts "Period covered: #{span.first} -> #{span.last}"
      puts
      puts "Sample (5 most recent):"
      rows.sort_by { |r| r[:occurred_at] }.last(5).reverse.each do |r|
        sku = ProductVariant.find_by(id: r[:product_variant_id])&.sku
        puts "  #{r[:occurred_at].strftime('%Y-%m-%d %H:%M')}  #{r[:kind].ljust(14)} #{r[:from_quantity]} -> #{r[:to_quantity]}  #{sku}"
      end
    end

    puts
    unless execute
      puts "DRY RUN — nothing written. Re-run with mode 'execute' to insert."
      next
    end

    existing = StockEvent.where(organisation_id: organisation.id, source: "erp_sync_log").count
    puts "Deleting #{existing} previously backfilled event(s)..." if existing.positive?
    StockEvent.where(organisation_id: organisation.id, source: "erp_sync_log").delete_all

    rows.each_slice(1000) { |slice| StockEvent.insert_all(slice) }
    puts "Inserted #{rows.size} event(s)."
    puts "Total StockEvents for this org: #{StockEvent.where(organisation_id: organisation.id).count}"
  end
end
