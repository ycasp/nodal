# Adds the missing half of every one-sided related-products link, so that A → B
# always has B → A alongside it.
#
# Links used to be stored in one direction only, while RelatedProductsFetcher
# reads `product_id = self` — so a link made on A's page was invisible from B,
# in the back office and in the shop. Saving a product now writes both halves;
# this backfills what was created before that.
#
# Idempotent (a pair that already has both halves is not touched) and dry-run by
# default. A pair that cannot be mirrored is reported and skipped, never raised.
#
#   bin/rails related_products:mirror                  # dry run, all organisations
#   bin/rails 'related_products:mirror[execute]'
#   bin/rails 'related_products:mirror[dry_run,perestrelo-cunha]'
namespace :related_products do
  desc "Backfill the missing direction of one-sided related-product links"
  task :mirror, [ :mode, :org_slug ] => :environment do |_t, args|
    mode    = args[:mode] || "dry_run"
    dry_run = mode != "execute"
    org     = args[:org_slug].present? ? Organisation.find_by!(slug: args[:org_slug]) : nil

    scope = RelatedProduct.all
    scope = scope.joins(:product).where(products: { organisation_id: org.id }) if org

    total    = scope.count
    one_way  = scope.without_mirror.count

    puts "#{dry_run ? '[SIMULACAO]' : '[EXECUCAO]'} #{org ? "org #{org.slug}" : 'todas as organisações'}"
    puts "ligações existentes: #{total}"
    puts "sem o sentido inverso: #{one_way}"

    if one_way.zero?
      puts "nada a fazer."
      next
    end

    result = RelatedProduct.transaction do
      RelatedProduct.create_missing_mirrors!(scope: scope, dry_run: dry_run)
    end

    # Names alone are ambiguous here: this catalog has 45 products called
    # "Moldura Criança" and 32 called "Conjunto de 2 Peças", so the id is what
    # makes a line auditable.
    labels = Product.where(id: result[:created].flatten.uniq).pluck(:id, :name, :sku).to_h do |id, name, sku|
      [ id, "#{name}#{sku.present? ? " (#{sku})" : ""} ##{id}" ]
    end

    result[:created].first(20).each do |from_id, to_id|
      puts "  + #{labels[from_id] || from_id} → #{labels[to_id] || to_id}"
    end
    puts "  ... e mais #{result[:created].size - 20}" if result[:created].size > 20

    result[:skipped].each do |skip|
      puts "  ! ignorado #{skip[:pair].inspect}: #{skip[:reason]}"
    end

    puts
    puts "#{dry_run ? 'seriam criadas' : 'criadas'}: #{result[:created].size}"
    puts "ignoradas: #{result[:skipped].size}"
    puts "corre com [execute] para aplicar." if dry_run
  end
end
