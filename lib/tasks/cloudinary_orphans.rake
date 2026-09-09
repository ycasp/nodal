namespace :cloudinary do
  desc "List Cloudinary assets that have no matching ActiveStorage::Blob in the DB. Optional [sample_size,csv_path]."
  task :orphans, [:sample_size, :csv_path] => :environment do |_, args|
    require "cloudinary"
    require "csv"

    sample_size = (args[:sample_size] || "50").to_i
    csv_path = args[:csv_path].presence

    human = ->(b) { ActiveSupport::NumberHelper.number_to_human_size(b || 0) }

    puts "=" * 78
    puts "Cloudinary orphan audit"
    puts "=" * 78

    folder = Cloudinary.config.folder.to_s
    puts "Cloud name : #{Cloudinary.config.cloud_name}"
    puts "Folder     : #{folder.presence || '(none)'}"

    db_keys = ActiveStorage::Blob.pluck(:key).to_set
    puts "DB blobs   : #{db_keys.size}"

    cloudinary_assets = []
    %w[image video raw].each do |resource_type|
      cursor = nil
      loop do
        response = Cloudinary::Api.resources(
          resource_type: resource_type,
          max_results: 500,
          next_cursor: cursor
        )
        (response["resources"] || []).each do |r|
          cloudinary_assets << r.merge("resource_type" => resource_type)
        end
        cursor = response["next_cursor"]
        break unless cursor
      end
    end
    puts "Cloud assets: #{cloudinary_assets.size}"

    orphans = cloudinary_assets.reject do |asset|
      public_id = asset["public_id"].to_s
      key = folder.present? && public_id.start_with?("#{folder}/") ? public_id.sub("#{folder}/", "") : public_id
      db_keys.include?(key)
    end

    puts ""
    puts "Orphans   : #{orphans.size} (#{human[orphans.sum { |o| o['bytes'].to_i }]})"
    puts ""

    by_format = orphans.group_by { |o| o["format"].to_s }.transform_values(&:size).sort_by { |_, n| -n }
    by_year   = orphans.group_by { |o| Time.iso8601(o["created_at"]).year rescue 'unknown' }.transform_values(&:size).sort
    by_folder = orphans.group_by { |o| File.dirname(o["public_id"].to_s) }.transform_values(&:size).sort_by { |_, n| -n }

    puts "By format:"
    by_format.first(10).each { |fmt, n| printf("  %-10s %6d\n", fmt.empty? ? "(none)" : fmt, n) }
    puts ""
    puts "By year of creation:"
    by_year.each { |y, n| printf("  %-10s %6d\n", y, n) }
    puts ""
    puts "By Cloudinary folder:"
    by_folder.first(10).each { |f, n| printf("  %-40s %6d\n", f, n) }
    puts ""

    puts "=" * 78
    puts "Random sample (#{[sample_size, orphans.size].min} of #{orphans.size})"
    puts "=" * 78
    printf("%-60s %-8s %10s %-12s %s\n", "public_id", "format", "bytes", "type", "created_at")
    orphans.sample(sample_size).sort_by { |o| o["created_at"].to_s }.each do |o|
      printf("%-60s %-8s %10s %-12s %s\n",
             o["public_id"].to_s[0, 60],
             o["format"].to_s[0, 8],
             human[o["bytes"].to_i],
             o["resource_type"][0, 12],
             o["created_at"])
    end

    if csv_path
      CSV.open(csv_path, "w") do |csv|
        csv << %w[public_id format bytes resource_type created_at folder secure_url]
        orphans.sort_by { |o| o["created_at"].to_s }.each do |o|
          csv << [
            o["public_id"],
            o["format"],
            o["bytes"],
            o["resource_type"],
            o["created_at"],
            File.dirname(o["public_id"].to_s),
            o["secure_url"]
          ]
        end
      end
      puts ""
      puts "Full list written to: #{csv_path} (#{orphans.size} rows)"
    end

    puts ""
    puts "=" * 78
  end
end
