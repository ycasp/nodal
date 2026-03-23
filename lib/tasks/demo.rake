# lib/tasks/demo.rake
#
# Usage:
#   rails demo:seed[peixe]
#   rails demo:seed[carnes]
#   rails demo:seed[frutas]
#   rails demo:seed[epi]
#   rails demo:seed[beleza]
#
# What it does:
#   - Wipes products, categories, orders, shopping lists for nodal-demo org
#   - Repopulates with industry-specific data from YAML
#   - Leaves customers, discounts and org untouched
#
# Add new verticals by creating a new YAML file in lib/tasks/demo/

require "yaml"

namespace :demo do

  DEMO_SLUG = "nodal-demo".freeze
  YAML_DIR  = Rails.root.join("lib/tasks/demo").freeze

  desc "Load industry-specific demo data. Usage: rails demo:seed[peixe]"
  task :seed, [:industry] => :environment do |_, args|
    industry = args[:industry]&.downcase

    unless industry
      available = Dir[YAML_DIR.join("*.yml")].map { |f| File.basename(f, ".yml") }.sort
      puts "❌ Please specify an industry. Example: rails demo:seed[peixe]"
      puts "   Available: #{available.join(', ')}"
      exit 1
    end

    yaml_path = YAML_DIR.join("#{industry}.yml")
    unless yaml_path.exist?
      available = Dir[YAML_DIR.join("*.yml")].map { |f| File.basename(f, ".yml") }.sort
      puts "❌ Unknown industry '#{industry}'. Available: #{available.join(', ')}"
      exit 1
    end

    org = Organisation.find_by(slug: DEMO_SLUG)
    unless org
      puts "❌ Demo org '#{DEMO_SLUG}' not found. Run db:seed first."
      exit 1
    end

    data = YAML.load_file(yaml_path, permitted_classes: [Symbol])
    label = data["label"] || industry.capitalize
    emoji = data["emoji"] || "📦"

    puts "🔄 Loading demo data: #{emoji} #{label}"
    puts "   Org: #{org.name} (#{org.slug})"
    puts ""

    ActiveRecord::Base.transaction do
      DemoLoader.new(org).wipe!
      puts "  🗑️  Wiped existing products, categories, orders and shopping lists"

      DemoLoader::FromYaml.new(org, data).seed!
    end

    puts ""
    puts "✅ Demo data loaded: #{emoji} #{label}"
    puts "   Storefront : /#{DEMO_SLUG}"
    puts "   Back-office: /#{DEMO_SLUG}/bo"
  end

end

# =============================================================================
# DEMO LOADER BASE
# =============================================================================
class DemoLoader
  attr_reader :org

  def initialize(org)
    @org = org
  end

  def wipe!
    # Order of deletion matters — respect FK constraints

    # Shopping lists
    ShoppingListItem
      .joins(:shopping_list)
      .where(shopping_lists: { organisation_id: org.id })
      .delete_all
    ShoppingList.where(organisation_id: org.id).delete_all

    # Orders
    order_ids = Order.where(organisation_id: org.id).pluck(:id)
    OrderItem.where(order_id: order_ids).delete_all
    Order.where(id: order_ids).delete_all

    # Category <> Product joins
    product_ids = Product.where(organisation_id: org.id).pluck(:id)
    CategoryProduct.where(product_id: product_ids).delete_all

    # Variant attribute values
    variant_ids = ProductVariant.where(organisation_id: org.id).pluck(:id)
    VariantAttributeValue.where(product_variant_id: variant_ids).delete_all

    # Product available values & product-attribute links
    ProductAvailableValue.where(product_id: product_ids).delete_all
    ProductProductAttribute.where(product_id: product_ids).delete_all

    # Variants
    ProductVariant.where(organisation_id: org.id).delete_all

    # Products
    Product.where(organisation_id: org.id).delete_all

    # Nullify category references in discounts before deleting categories
    category_ids = Category.where(organisation_id: org.id).pluck(:id)
    ProductDiscount.where(category_id: category_ids).update_all(category_id: nil) if category_ids.any?
    CustomerProductDiscount.where(category_id: category_ids).update_all(category_id: nil) if category_ids.any?

    # Categories
    Category.where(organisation_id: org.id).delete_all
  end

  # ---------------------------------------------------------------------------
  # Helpers shared across all industry loaders
  # ---------------------------------------------------------------------------

  def create_category!(name:, slug:, description:, color:, position:)
    Category.create!(
      organisation: org,
      name:         name,
      slug:         "#{DEMO_SLUG}-#{slug}",
      description:  description,
      color:        color,
      position:     position
    )
  end

  # Simple product — updates the auto-created default variant with stock info
  def create_simple_product!(category:, name:, sku:, price_cents:, unit_desc:, min_qty:, stock: 200, description: nil)
    slug = "#{DEMO_SLUG}-#{sku.downcase.gsub(/[^a-z0-9]/, '-')}"
    product = Product.create!(
      organisation:    org,
      category:        category,
      name:            name,
      slug:            slug,
      sku:             sku,
      description:     description,
      unit_price:      price_cents,
      unit_description: unit_desc,
      min_quantity:    min_qty,
      available:       true,
      has_variants:    false
    )

    # Update the auto-created default variant with stock
    product.product_variants.first!.update!(
      stock_quantity: stock,
      track_stock:    true
    )

    product
  end

  # Product with multiple named variants and proper attribute configuration
  def create_variant_product!(category:, name:, sku:, unit_desc:, min_qty:, attribute_name:, description: nil, variants: [])
    slug = "#{DEMO_SLUG}-#{sku.downcase.gsub(/[^a-z0-9]/, '-')}"
    base_price = variants.first[:price_cents]

    product = Product.create!(
      organisation:    org,
      category:        category,
      name:            name,
      slug:            slug,
      sku:             sku,
      description:     description,
      unit_price:      base_price,
      unit_description: unit_desc,
      min_quantity:    min_qty,
      available:       true,
      has_variants:    true,
      variants_generated: true
    )

    # 1. Find or create the ProductAttribute for this org
    attr = ProductAttribute.find_or_create_by!(organisation: org, name: attribute_name) do |a|
      a.position = ProductAttribute.where(organisation: org).count + 1
    end

    # 2. Link attribute to product
    ProductProductAttribute.create!(product: product, product_attribute: attr, position: 1)

    # 3. Create each variant with its attribute value
    variants.each_with_index do |v, i|
      attr_value = ProductAttributeValue.find_or_create_by!(product_attribute: attr, value: v[:name]) do |av|
        av.position = i + 1
      end

      ProductAvailableValue.create!(product: product, product_attribute_value: attr_value)

      pv = ProductVariant.create!(
        organisation:         org,
        product:              product,
        sku:                  "#{sku}-#{v[:sku_suffix]}",
        name:                 v[:name],
        unit_price_cents:     v[:price_cents],
        unit_price_currency:  org.currency,
        stock_quantity:       v[:stock] || 150,
        track_stock:          true,
        available:            true,
        is_default:           i == 0,
        position:             i + 1
      )

      VariantAttributeValue.create!(product_variant: pv, product_attribute_value: attr_value)
    end

    product
  end

  def create_order!(customer:, status:, placed_at: nil, items: [])
    order = Order.create!(
      organisation:             org,
      customer:                 customer,
      order_number:             "DEMO-#{SecureRandom.hex(4).upcase}",
      status:                   status,
      payment_status:           status == "completed" ? "paid" : "pending",
      placed_at:                placed_at,
      receive_on:               placed_at ? placed_at.to_date + 3.days : nil,
      shipping_amount_cents:    org.shipping_cost_cents,
      shipping_amount_currency: org.shipping_cost_currency,
      delivery_method:          "delivery"
    )

    items.each do |product, variant, qty|
      OrderItem.create!(
        order:            order,
        product:          product,
        product_variant:  variant,
        quantity:         qty,
        unit_price:       variant.unit_price_cents,
        discount_percentage: 0.0
      )
    end

    order
  end

  def create_shopping_list!(customer:, name:, notes: nil, items: [])
    list = ShoppingList.create!(
      organisation: org,
      customer:     customer,
      name:         name,
      notes:        notes
    )

    items.each do |product, variant, qty|
      ShoppingListItem.create!(
        shopping_list:    list,
        product:          product,
        product_variant:  variant,
        quantity:         qty
      )
    end

    list
  end

end

# =============================================================================
# GENERIC YAML-DRIVEN LOADER
# =============================================================================
class DemoLoader::FromYaml < DemoLoader

  SHOPPING_LIST_NAMES = [
    "Encomenda Semanal",
    "Favoritos",
    "Reposição Mensal"
  ].freeze

  def initialize(org, data)
    super(org)
    @data = data
  end

  def seed!
    emoji = @data["emoji"] || "📦"
    label = @data["label"] || "Catálogo"

    puts "  #{emoji} Seeding #{label}..."

    categories = seed_categories!
    products   = seed_products!(categories)
    seed_orders!(products)
    seed_shopping_lists!(products)

    puts "  ✅ #{org.products.count} produtos | #{org.orders.count} encomendas"
  end

  private

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------
  def seed_categories!
    cat_map = {}
    (@data["categories"] || []).each_with_index do |cat, i|
      cat_map[cat["name"]] = create_category!(
        name:        cat["name"],
        slug:        cat["slug"],
        description: cat["description"] || "",
        color:       cat["color"] || "#607D8B",
        position:    i + 1
      )
    end
    cat_map
  end

  # ---------------------------------------------------------------------------
  # Products (simple + variant)
  # ---------------------------------------------------------------------------
  def seed_products!(categories)
    all_products = []

    # Simple products
    (@data["products"] || []).each do |p|
      category = categories[p["category"]]
      product = create_simple_product!(
        category:    category,
        name:        p["name"],
        sku:         p["sku"],
        price_cents: p["price"],
        unit_desc:   p["unit"],
        min_qty:     p["min_qty"] || 1,
        stock:       p["stock"] || 200,
        description: p["description"]
      )
      all_products << product
    end

    simple_count = all_products.size
    puts "    ✅ #{simple_count} produtos simples"

    # Variant products
    (@data["variant_products"] || []).each do |vp|
      category = categories[vp["category"]]
      variant_data = (vp["variants"] || []).map do |v|
        {
          name:        v["name"],
          sku_suffix:  v["sku_suffix"],
          price_cents: v["price"],
          stock:       v["stock"] || 150
        }
      end

      product = create_variant_product!(
        category:       category,
        name:           vp["name"],
        sku:            vp["sku"],
        unit_desc:      vp["unit"],
        min_qty:        vp["min_qty"] || 1,
        attribute_name: vp["attribute"],
        description:    vp["description"],
        variants:       variant_data
      )
      all_products << product
    end

    variant_count = all_products.size - simple_count
    puts "    ✅ #{variant_count} produtos com variantes" if variant_count > 0

    all_products
  end

  # ---------------------------------------------------------------------------
  # Auto-generated orders
  # ---------------------------------------------------------------------------
  def seed_orders!(products)
    customers = Customer.where(organisation_id: org.id).limit(3).to_a
    return if customers.empty? || products.empty?

    completed_count = 0
    in_process_count = 0

    customers.each do |customer|
      # 2 completed orders
      [40, 12].each do |days_ago|
        items = pick_random_items(products, 3)
        create_order!(
          customer:  customer,
          status:    "completed",
          placed_at: days_ago.days.ago,
          items:     items
        )
        completed_count += 1
      end

      # 1 in_process order
      items = pick_random_items(products, 3)
      create_order!(
        customer: customer,
        status:   "in_process",
        items:    items
      )
      in_process_count += 1
    end

    puts "    ✅ #{completed_count + in_process_count} encomendas (#{completed_count} concluídas + #{in_process_count} em curso)"
  end

  # ---------------------------------------------------------------------------
  # Auto-generated shopping lists
  # ---------------------------------------------------------------------------
  def seed_shopping_lists!(products)
    customers = Customer.where(organisation_id: org.id).limit(3).to_a
    return if customers.empty? || products.empty?

    customers.each_with_index do |customer, i|
      items = pick_random_items(products, 3)
      create_shopping_list!(
        customer: customer,
        name:     SHOPPING_LIST_NAMES[i] || "Lista #{i + 1}",
        items:    items
      )
    end

    puts "    ✅ #{customers.size} listas de compras (1 por cliente)"
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Pick n random products, resolve a variant for each, and compute a quantity
  def pick_random_items(products, n)
    sampled = products.sample(n)
    sampled.map do |product|
      variant = pick_variant(product)
      qty = product.min_quantity * rand(2..5)
      [product, variant, qty]
    end
  end

  # For variant products pick a random variant; for simple products use the default
  def pick_variant(product)
    if product.has_variants?
      product.product_variants.where(is_default: false).sample ||
        product.product_variants.first!
    else
      product.product_variants.first!
    end
  end
end
