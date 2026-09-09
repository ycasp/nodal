# frozen_string_literal: true

# One-off demo seeder: creates a small "Aviminho" chicken catalog in a demo org
# for outreach screen-recordings. Idempotent (skips SKUs that already exist).
#
#   rails 'demo:seed_aviminho[nodal-demo,/tmp/aviminho_demo,dry_run]'
#   RAILS_ENV=production CLOUDINARY_URL=... SECRET_KEY_BASE=dummy \
#     rails 'demo:seed_aviminho[nodal-demo,/tmp/aviminho_demo,execute]'
namespace :demo do
  desc "Seed the Aviminho HORECA chicken demo products into an org"
  task :seed_aviminho, [:org_slug, :images_dir, :mode] => :environment do |_t, args|
    org_slug   = args[:org_slug]
    images_dir = args[:images_dir]
    mode       = args[:mode] || "dry_run"
    dry_run    = mode != "execute"

    org = Organisation.find_by(slug: org_slug)
    abort "Org '#{org_slug}' not found" unless org

    category_name = "Frango Corte Horeca"

    # name, sku, code, price_cents (per kg, INVENTED — catalog says "A consultar"),
    # approx weight, image filename
    products = [
      { name: "Carne Picada de Frango",      sku: "AVI-1052", code: "1052", price: 449, weight: "± 2 Kg", img: "1052_carne_picada.png" },
      { name: "Traseiro s/Osso e c/Pele",    sku: "AVI-1053", code: "1053", price: 549, weight: "± 3 Kg", img: "1053_traseiro_cpele.png" },
      { name: "Traseiro s/Osso e s/Pele",    sku: "AVI-1058", code: "1058", price: 599, weight: "± 3 Kg", img: "1058_traseiro_spele.png" },
      { name: "Coxa s/Osso e c/Pele",        sku: "AVI-1054", code: "1054", price: 649, weight: "± 3 Kg", img: "1054_coxa_cpele.png" }
    ]

    puts "=" * 64
    puts dry_run ? "DEMO SEED AVIMINHO (DRY RUN)" : "DEMO SEED AVIMINHO (EXECUTE)"
    puts "Org: #{org.name} (#{org.slug}) | currency=#{org.currency}"
    puts "Category: #{category_name}"
    puts "Images: #{images_dir}"
    puts "=" * 64

    category = nil
    unless dry_run
      category = org.categories.find_or_create_by!(name: category_name) do |c|
        c.slug = category_name.parameterize if c.respond_to?(:slug=)
      end
    end

    products.each do |p|
      existing = org.products.find_by(sku: p[:sku])
      if existing
        puts "SKIP  #{p[:sku]} — already exists (#{existing.name})"
        next
      end

      desc = "Frango fresco, embalado em bandeja. " \
             "Validade: 5 dias. Peso por unidade aprox.: #{p[:weight]}. " \
             "Origem: variada. Código: #{p[:code]}."

      img_path = File.join(images_dir, p[:img])
      has_img  = File.exist?(img_path)

      if dry_run
        puts "CREATE #{p[:sku]} | #{p[:name]} | €#{format('%.2f', p[:price] / 100.0)}/kg | photo=#{has_img ? p[:img] : 'MISSING'}"
        next
      end

      product = org.products.create!(
        name: p[:name],
        sku: p[:sku],
        description: desc,
        unit_price: p[:price],
        unit_description: "kg",
        has_variants: false,
        published: true
      )
      product.categories << category unless product.categories.include?(category)

      if has_img
        product.photos.attach(io: File.open(img_path), filename: p[:img], content_type: "image/png")
        puts "CREATE #{p[:sku]} | #{p[:name]} | €#{format('%.2f', p[:price] / 100.0)}/kg | photo attached"
      else
        puts "CREATE #{p[:sku]} | #{p[:name]} | €#{format('%.2f', p[:price] / 100.0)}/kg | NO PHOTO (#{img_path})"
      end
    end

    puts "=" * 64
    puts dry_run ? "Dry run done. Re-run with mode=execute to apply." : "Done."
    puts "=" * 64
  end
end
