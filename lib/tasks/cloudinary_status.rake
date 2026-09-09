namespace :cloudinary do
  desc "Show current Cloudinary plan usage + list non-image resources (video, raw)"
  task :status, [:list_videos] => :environment do |_, args|
    require "cloudinary"

    list_videos = args[:list_videos].to_s == "true"
    human = ->(b) { ActiveSupport::NumberHelper.number_to_human_size(b || 0) }

    puts "=" * 78
    puts "Cloudinary status"
    puts "=" * 78

    # ---------- Plan usage (1 API call, dirt cheap) ----------
    usage = Cloudinary::Api.usage
    puts ""
    puts "PLAN: #{usage['plan']}"
    puts "Last updated by Cloudinary: #{usage['last_updated']}"
    puts ""
    puts "Storage    : #{human[usage.dig('storage', 'usage')]} / #{human[usage.dig('storage', 'limit')]} (#{usage.dig('storage', 'used_percent')&.round(1)}%)"
    puts "Bandwidth  : #{human[usage.dig('bandwidth', 'usage')]} / #{human[usage.dig('bandwidth', 'limit')]} (#{usage.dig('bandwidth', 'used_percent')&.round(1)}%)"
    puts "Credits    : #{usage.dig('credits', 'usage')&.round(2)} / #{usage.dig('credits', 'limit')} (#{usage.dig('credits', 'used_percent')&.round(1)}%)"
    puts "Transformations: #{usage.dig('transformations', 'usage')}"
    puts "Total resources: #{usage['resources']} (originals #{usage['resources_originals']}, derived #{usage['resources_derived']})"

    # ---------- DB snapshot ----------
    db_blobs = ActiveStorage::Blob.count
    db_bytes = ActiveStorage::Blob.sum(:byte_size)
    db_unattached = ActiveStorage::Blob.unattached.count
    puts ""
    puts "Active Storage DB:"
    puts "  Total blobs       : #{db_blobs}"
    puts "  Total bytes       : #{human[db_bytes]}"
    puts "  Unattached blobs  : #{db_unattached} (will be purged on next sweep)"
    puts ""
    diff = (usage['resources_originals'] || 0) - db_blobs
    if diff > 0
      puts "  ⚠️  Cloudinary has #{diff} originals NOT tracked in DB — orphan candidates"
    end

    # ---------- Non-image resources (find that mystery video!) ----------
    puts ""
    puts "VIDEO resources on Cloudinary (#{human[(usage.dig('storage_by_resource_type', 'video') || 0)]} reported)"
    puts "-" * 78

    video_response = Cloudinary::Api.resources(resource_type: "video", max_results: 50)
    videos = video_response["resources"] || []

    if videos.empty?
      puts "  None found via API."
    else
      total_bytes = videos.sum { |r| r["bytes"].to_i }
      puts "  #{videos.size} resources, #{human[total_bytes]} total"
      puts ""
      printf("  %-50s %10s %12s %s\n", "Public ID", "Bytes", "Format", "Created")
      videos.sort_by { |r| -r["bytes"].to_i }.first(20).each do |r|
        printf("  %-50s %10s %12s %s\n",
               r["public_id"].to_s[0, 50],
               human[r["bytes"].to_i],
               r["format"].to_s,
               r["created_at"])
      end

      if videos.size == 50
        puts "  ... possibly more (capped at 50; pass [true] to recurse)"
      end
    end

    # ---------- Raw resources ----------
    puts ""
    puts "RAW resources on Cloudinary"
    puts "-" * 78

    raw_response = Cloudinary::Api.resources(resource_type: "raw", max_results: 20)
    raws = raw_response["resources"] || []
    if raws.empty?
      puts "  None found."
    else
      puts "  #{raws.size} resources"
      raws.sort_by { |r| -r["bytes"].to_i }.first(10).each do |r|
        printf("  %-60s %10s\n", r["public_id"].to_s[0, 60], human[r["bytes"].to_i])
      end
    end

    puts ""
    puts "=" * 78
  end
end
