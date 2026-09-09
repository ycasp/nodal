require "csv"

namespace :cleanup do
  desc "Destroy customers whose external_id appears in a CSV, optionally filtered by a column=value. Usage: rake 'cleanup:stranded_customers[org_slug,csv_path,id_column,filter_column,filter_value,dry_run|execute]'"
  task :stranded_customers, [:org_slug, :csv_path, :external_id_column, :filter_column, :filter_value, :mode] => :environment do |_t, args|
    org_slug = args[:org_slug].to_s.strip
    csv_path = args[:csv_path].to_s.strip
    column = args[:external_id_column].to_s.strip.presence || "Numero"
    filter_column = args[:filter_column].to_s.strip.presence
    filter_value = args[:filter_value].to_s.strip
    mode = args[:mode].to_s.strip.downcase
    abort "org_slug is required" if org_slug.blank?
    abort "csv_path is required" if csv_path.blank?
    abort "csv not found at #{csv_path}" unless File.exist?(csv_path)
    abort "mode must be dry_run or execute" unless %w[dry_run execute].include?(mode)

    org = Organisation.find_by!(slug: org_slug)

    rows = CSV.read(csv_path, headers: true)
    if filter_column
      before = rows.size
      rows = rows.select { |r| r[filter_column].to_s.strip == filter_value }
      puts "CSV: #{before} rows total, #{rows.size} match #{filter_column}=#{filter_value}"
    else
      puts "CSV: #{rows.size} rows total (no filter)"
    end

    bad_external_ids = rows.map { |row| row[column].to_s.strip }.reject(&:empty?).uniq
    abort "No values found in column '#{column}' after filter" if bad_external_ids.empty?
    puts "Distinct external_ids from CSV: #{bad_external_ids.size}"

    candidates = org.customers.where(external_id: bad_external_ids).to_a
    puts "Nodal customers (org=#{org_slug}) matching: #{candidates.size}"

    if candidates.empty?
      puts "Nothing to clean up. Exiting."
      next
    end

    with_placed_orders = Customer.where(id: candidates.map(&:id))
                                 .joins(:orders).where.not(orders: { placed_at: nil })
                                 .distinct.to_a
    if with_placed_orders.any?
      puts ""
      puts "ABORT: #{with_placed_orders.size} candidate(s) have placed orders. Refusing to destroy."
      with_placed_orders.first(20).each do |c|
        puts "  id=#{c.id} external_id=#{c.external_id} email=#{c.email} placed_orders=#{c.orders.placed.count}"
      end
      abort "Re-run after deciding what to do with these"
    end

    drafts_destroyed = Customer.where(id: candidates.map(&:id)).joins(:orders).where(orders: { placed_at: nil }).distinct.count
    puts "Note: #{drafts_destroyed} candidate(s) have draft carts (will be removed with the customer)." if drafts_destroyed > 0

    invited_or_signed_in = candidates.select do |c|
      c.invitation_sent_at.present? || c.invitation_accepted_at.present? || (c.sign_in_count.to_i > 0)
    end
    if invited_or_signed_in.any?
      puts ""
      puts "WARNING: #{invited_or_signed_in.size} candidate(s) were invited or have signed in:"
      invited_or_signed_in.first(10).each do |c|
        puts "  id=#{c.id} external_id=#{c.external_id} email=#{c.email} invited_at=#{c.invitation_sent_at} signed_in=#{c.sign_in_count}"
      end
      puts "(They will still be destroyed if you run with execute.)"
    end

    puts ""
    puts "Sample of candidates to destroy:"
    candidates.first(15).each do |c|
      puts "  id=#{c.id} external_id=#{c.external_id} active=#{c.active.inspect} email=#{c.email} company=#{c.company_name}"
    end

    if mode == "dry_run"
      puts ""
      puts "Dry-run only. Re-run with mode=execute to destroy #{candidates.size} customer(s)."
      next
    end

    puts ""
    print "Destroying #{candidates.size} customer(s)... "
    destroyed = 0
    failed = []
    Customer.transaction do
      candidates.each do |c|
        if c.destroy
          destroyed += 1
        else
          failed << [c.id, c.errors.full_messages.join("; ")]
        end
      end
      if failed.any?
        puts ""
        puts "Failures:"
        failed.first(20).each { |id, msg| puts "  id=#{id}: #{msg}" }
        raise ActiveRecord::Rollback
      end
    end

    if failed.any?
      puts "Rolled back. #{destroyed} would have been destroyed."
    else
      puts "done. Destroyed #{destroyed} customer(s)."
    end
  end
end
