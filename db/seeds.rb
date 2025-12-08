# frozen_string_literal: true

# =============================================================================
# NODAL SEED FILE
# =============================================================================
# This seed creates comprehensive test data for all features and authorization
# scenarios. Run with: bin/rails db:seed
#
# All passwords: 123123
# =============================================================================

require "open-uri"

puts "=" * 70
puts "SEEDING NODAL DATABASE"
puts "=" * 70

# -----------------------------------------------------------------------------
# CLEANUP (respecting foreign key constraints)
# -----------------------------------------------------------------------------
puts "\nCleaning up existing data..."

OrderItem.destroy_all
Order.destroy_all
Address.destroy_all
Product.destroy_all
Category.destroy_all
Customer.destroy_all
OrgMember.destroy_all
Member.destroy_all
Organisation.destroy_all

puts "All data destroyed."

# =============================================================================
# ORGANISATION 1: B2B Groceries (Full-featured, main testing org)
# =============================================================================
puts "\n" + "=" * 70
puts "ORGANISATION 1: B2B Groceries"
puts "=" * 70

groceries = Organisation.create!(
  name: "B2B Groceries",
  billing_email: "billing@b2bgroceries.com"
)

# Organisation billing address
Address.create!(
  addressable: groceries,
  address_type: "billing",
  street_name: "123 Commerce Street, Suite 500",
  postal_code: "10001",
  city: "New York",
  country: "United States"
)

# -----------------------------------------------------------------------------
# Members with different roles
# -----------------------------------------------------------------------------
puts "  Creating members with different roles..."

# OWNER - Full access
groceries_owner = Member.create!(
  email: "owner@groceries.com",
  password: "123123",
  first_name: "Alice",
  last_name: "Owner"
)
OrgMember.create!(
  organisation: groceries,
  member: groceries_owner,
  role: "owner",
  active: true,
  joined_at: 1.year.ago
)

# ADMIN - Administrative access
groceries_admin = Member.create!(
  email: "admin@groceries.com",
  password: "123123",
  first_name: "Bob",
  last_name: "Admin"
)
OrgMember.create!(
  organisation: groceries,
  member: groceries_admin,
  role: "admin",
  active: true,
  joined_at: 6.months.ago
)

# MEMBER - Limited access
groceries_member = Member.create!(
  email: "member@groceries.com",
  password: "123123",
  first_name: "Charlie",
  last_name: "Member"
)
OrgMember.create!(
  organisation: groceries,
  member: groceries_member,
  role: "member",
  active: true,
  joined_at: 3.months.ago
)

# INACTIVE MEMBER - Should be denied access
groceries_inactive_member = Member.create!(
  email: "inactive@groceries.com",
  password: "123123",
  first_name: "Dave",
  last_name: "Inactive"
)
OrgMember.create!(
  organisation: groceries,
  member: groceries_inactive_member,
  role: "admin",
  active: false,
  joined_at: 1.year.ago
)

# -----------------------------------------------------------------------------
# Categories
# -----------------------------------------------------------------------------
puts "  Creating categories..."

groceries_categories = {}
%w[Beverages Oils\ &\ Condiments Baking Dairy Seafood Fruits Vegetables Meat].each do |name|
  groceries_categories[name] = Category.create!(name: name, organisation: groceries)
end

# -----------------------------------------------------------------------------
# Products (including unavailable for testing filters)
# -----------------------------------------------------------------------------
puts "  Creating products..."

groceries_products_data = [
  # Available products (image_id = specific Lorem Picsum image for consistency)
  { name: "Organic Coffee Beans", slug: "organic-coffee-beans", sku: "COF-ORG-001",
    description: "Premium organic coffee beans, medium roast with rich flavor.",
    category: "Beverages", unit_price: 2499, unit_description: "lb", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935717/B00MW62LE8.MAIN_1200x_e6vq6e.webp" },
  { name: "Premium Olive Oil", slug: "premium-olive-oil", sku: "OIL-PRE-002",
    description: "Extra virgin olive oil from Mediterranean olives.",
    category: "Oils & Condiments", unit_price: 1850, unit_description: "L", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935121/tgs4yxtgxnoekzrq8qir_800x_big1no.webp"},
  { name: "Artisan Sourdough Flour", slug: "artisan-sourdough-flour", sku: "FLR-SOU-003",
    description: "High-protein flour perfect for artisan bread baking.",
    category: "Baking", unit_price: 1299, unit_description: "kg", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935115/81yNrU9IatL_eysbcp.webp" },
  { name: "Fresh Mozzarella", slug: "fresh-mozzarella", sku: "CHE-MOZ-004",
    description: "Creamy fresh mozzarella, perfect for salads and pizza.",
    category: "Dairy", unit_price: 875, unit_description: "kg", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935111/16910f5ef4b1ab97a12313f86bb6b54a_rd0xj1.webp" },
  { name: "Grass-Fed Butter", slug: "grass-fed-butter", sku: "DAI-BUT-005",
    description: "Rich and creamy butter from grass-fed cows.",
    category: "Dairy", unit_price: 650, unit_description: "lb", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935118/butter-2048px-3645_hxxclc.webp" },
  { name: "Wild-Caught Salmon", slug: "wild-caught-salmon", sku: "SEA-SAL-006",
    description: "Fresh wild-caught Atlantic salmon fillets.",
    category: "Seafood", unit_price: 3200, unit_description: "lb", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935110/10_1_Fish_1_kbfpba.webp" },
  { name: "Organic Apples", slug: "organic-apples", sku: "FRU-APP-007",
    description: "Fresh, crisp red apples, ideal for snacking or baking.",
    category: "Fruits", unit_price: 299, unit_description: "lb", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935112/61kmJoXKqWL_itwbjq.webp" },
  { name: "Aged Parmesan", slug: "aged-parmesan", sku: "CHE-PAR-008",
    description: "24-month aged Italian Parmigiano-Reggiano cheese.",
    category: "Dairy", unit_price: 2499, unit_description: "kg", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935109/0a1755b0-59b1-49aa-bc88-fd7b25da4067.__CR0_0_300_300_PT0_SX300_V1____fucl7j.webp" },
  { name: "Organic Honey", slug: "organic-honey", sku: "SWT-HON-009",
    description: "Raw organic wildflower honey from local apiaries.",
    category: "Baking", unit_price: 1599, unit_description: "jar", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935120/Organic_ThisHoney_24oz_b5f7b581-b402-4e93-8d58-9961f4b0caf2_sxh1ff.webp" },
  { name: "Fresh Basil", slug: "fresh-basil", sku: "VEG-BAS-010",
    description: "Aromatic fresh basil leaves, hydroponically grown.",
    category: "Vegetables", unit_price: 450, unit_description: "bunch", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935119/large_766df0b7-9df4-4847-b245-290a4995ee1d_dgat91.webp" },
  { name: "Prime Ribeye Steak", slug: "prime-ribeye-steak", sku: "MEA-RIB-011",
    description: "USDA Prime grade ribeye, dry-aged for 21 days.",
    category: "Meat", unit_price: 4599, unit_description: "lb", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935114/81dPJmdo-6L_xwlm9y.webp" },
  { name: "Balsamic Vinegar", slug: "balsamic-vinegar", sku: "OIL-BAL-012",
    description: "Aged balsamic vinegar from Modena, Italy.",
    category: "Oils & Condiments", unit_price: 2199, unit_description: "bottle", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935122/vill-antica-balsamic-vinegar-of-modena-over-25-years-old-12987-1s-2987_flo7wg.jpg" },
  { name: "Organic Lemons", slug: "organic-lemons", sku: "FRU-LEM-013",
    description: "Fresh organic lemons, perfect for cooking and drinks.",
    category: "Fruits", unit_price: 199, unit_description: "lb", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935113/71YrpRTwTKL_sqigxt.webp" },
  { name: "Atlantic Shrimp", slug: "atlantic-shrimp", sku: "SEA-SHR-014",
    description: "Large wild-caught Atlantic shrimp, shell-on.",
    category: "Seafood", unit_price: 2899, unit_description: "lb", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935118/cooked-peel-and-eat-shrimp-by-the-pound.f0c64227a1e4200c2499ae7d19f885c6_jxjlam.webp" },
  { name: "Whole Wheat Flour", slug: "whole-wheat-flour", sku: "FLR-WHT-015",
    description: "Stone-ground whole wheat flour for healthy baking.",
    category: "Baking", unit_price: 899, unit_description: "kg", available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935115/91nOP4BaNUL_rqncoz.webp" },

  # UNAVAILABLE products (for testing filters)
  { name: "Seasonal Black Truffles", slug: "seasonal-black-truffles", sku: "VEG-TRU-016",
    description: "Rare black truffles - currently out of season.",
    category: "Vegetables", unit_price: 15000, unit_description: "oz", available: false,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935111/61djJqZeg8L_k0enur.webp" },
  { name: "A5 Wagyu Beef", slug: "a5-wagyu-beef", sku: "MEA-WAG-017",
    description: "Premium Japanese A5 Wagyu - temporarily unavailable.",
    category: "Meat", unit_price: 25000, unit_description: "lb", available: false,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764935111/61djJqZeg8L_k0enur.webp" }
]

groceries_products = {}
groceries_products_data.each do |data|
  product = Product.create!(
    organisation: groceries,
    name: data[:name],
    slug: data[:slug],
    sku: data[:sku],
    description: data[:description],
    category: groceries_categories[data[:category]],
    unit_price: data[:unit_price],
    unit_description: data[:unit_description],
    min_quantity: 1,
    min_quantity_type: "unit",
    available: data[:available]
  )
  groceries_products[data[:slug]] = product

  # Attach product photo (from URL if provided, otherwise from Lorem Picsum)
  image_url = data[:image_url] || "https://picsum.photos/id/#{data[:image_id]}/400/300"
  file = URI.open(image_url)
  product.photo.attach(io: file, filename: "#{data[:slug]}.jpg", content_type: "image/jpeg")
end
puts "  Attached photos to #{groceries_products.count} products"

# -----------------------------------------------------------------------------
# Customers with billing + multiple shipping addresses
# -----------------------------------------------------------------------------
puts "  Creating customers with addresses..."

groceries_customers_data = [
  {
    company_name: "Hans' Bakery",
    contact_name: "Hans Hansensen",
    email: "hans@bakery.com",
    active: true,
    billing: { street_name: "45 Baker Street", postal_code: "10002", city: "New York", country: "United States" },
    shipping: [
      { street_name: "45 Baker Street (Main Kitchen)", postal_code: "10002", city: "New York", country: "United States" },
      { street_name: "78 Production Lane (Warehouse)", postal_code: "10003", city: "Brooklyn", country: "United States" }
    ]
  },
  {
    company_name: "Maria's Cafe",
    contact_name: "Maria Santos",
    email: "maria@cafe.com",
    active: true,
    billing: { street_name: "123 Coffee Avenue", postal_code: "10004", city: "New York", country: "United States" },
    shipping: [
      { street_name: "123 Coffee Avenue", postal_code: "10004", city: "New York", country: "United States" }
    ]
  },
  {
    company_name: "The Green Kitchen",
    contact_name: "Oliver Green",
    email: "oliver@greenkitchen.com",
    active: true,
    billing: { street_name: "56 Veggie Road", postal_code: "10005", city: "New York", country: "United States" },
    shipping: [
      { street_name: "56 Veggie Road (Restaurant)", postal_code: "10005", city: "New York", country: "United States" },
      { street_name: "89 Farm Fresh Blvd (Prep Kitchen)", postal_code: "10006", city: "Brooklyn", country: "United States" },
      { street_name: "12 Organic Way (Catering Hub)", postal_code: "10007", city: "Queens", country: "United States" }
    ]
  },
  {
    company_name: "Nordic Delights",
    contact_name: "Erik Lindqvist",
    email: "erik@nordicdelights.com",
    active: true,
    billing: { street_name: "234 Scandinavia Street", postal_code: "10008", city: "New York", country: "United States" },
    shipping: [
      { street_name: "234 Scandinavia Street", postal_code: "10008", city: "New York", country: "United States" }
    ]
  },
  {
    company_name: "Fresh & Co Restaurant",
    contact_name: "Sophie Martin",
    email: "sophie@freshandco.com",
    active: true,
    billing: { street_name: "567 Gourmet Plaza", postal_code: "10009", city: "New York", country: "United States" },
    shipping: [
      { street_name: "567 Gourmet Plaza (Main)", postal_code: "10009", city: "New York", country: "United States" },
      { street_name: "890 Kitchen Lane (Events)", postal_code: "10010", city: "Manhattan", country: "United States" }
    ]
  },
  {
    company_name: "Urban Bistro",
    contact_name: "James Chen",
    email: "james@urbanbistro.com",
    active: true,
    billing: { street_name: "321 City Center", postal_code: "10011", city: "New York", country: "United States" },
    shipping: [
      { street_name: "321 City Center", postal_code: "10011", city: "New York", country: "United States" }
    ]
  },
  {
    company_name: "Sunrise Hotel",
    contact_name: "Anna Kowalski",
    email: "anna@sunrisehotel.com",
    active: true,
    billing: { street_name: "1 Hotel Boulevard", postal_code: "10012", city: "New York", country: "United States" },
    shipping: [
      { street_name: "1 Hotel Boulevard - Kitchen Entrance", postal_code: "10012", city: "New York", country: "United States" },
      { street_name: "1 Hotel Boulevard - Restaurant Wing", postal_code: "10012", city: "New York", country: "United States" },
      { street_name: "1 Hotel Boulevard - Banquet Hall", postal_code: "10012", city: "New York", country: "United States" }
    ]
  },
  {
    company_name: "The Corner Deli",
    contact_name: "Michael Brown",
    email: "michael@cornerdeli.com",
    active: true,
    billing: { street_name: "99 Corner Street", postal_code: "10013", city: "New York", country: "United States" },
    shipping: [
      { street_name: "99 Corner Street", postal_code: "10013", city: "New York", country: "United States" }
    ]
  },
  {
    company_name: "Golden Spoon Catering",
    contact_name: "Isabella Romano",
    email: "isabella@goldenspoon.com",
    active: true,
    billing: { street_name: "456 Catering Drive", postal_code: "10014", city: "New York", country: "United States" },
    shipping: [
      { street_name: "456 Catering Drive - Warehouse", postal_code: "10014", city: "New York", country: "United States" },
      { street_name: "789 Event Center", postal_code: "10015", city: "New York", country: "United States" }
    ]
  },
  {
    company_name: "Blue Ocean Fish Bar",
    contact_name: "Thomas Fischer",
    email: "thomas@blueocean.com",
    active: true,
    billing: { street_name: "22 Harbor View", postal_code: "10016", city: "New York", country: "United States" },
    shipping: [
      { street_name: "22 Harbor View", postal_code: "10016", city: "New York", country: "United States" }
    ]
  },
  {
    company_name: "Wholesome Eats",
    contact_name: "Emma Wilson",
    email: "emma@wholesomeeats.com",
    active: true,
    billing: { street_name: "88 Health Street", postal_code: "10017", city: "New York", country: "United States" },
    shipping: [
      { street_name: "88 Health Street", postal_code: "10017", city: "New York", country: "United States" }
    ]
  },
  # INACTIVE customer (for testing access control)
  {
    company_name: "Closed Kitchen (INACTIVE)",
    contact_name: "Former Owner",
    email: "closed@kitchen.com",
    active: false,
    billing: { street_name: "0 Nowhere Street", postal_code: "00000", city: "New York", country: "United States" },
    shipping: []
  }
]

groceries_customers = {}
groceries_customers_data.each do |data|
  customer = Customer.create!(
    organisation: groceries,
    company_name: data[:company_name],
    contact_name: data[:contact_name],
    email: data[:email],
    password: "123123",
    active: data[:active]
  )
  groceries_customers[data[:email]] = customer

  # Billing address
  Address.create!(
    addressable: customer,
    address_type: "billing",
    **data[:billing]
  )

  # Shipping addresses
  data[:shipping].each do |addr|
    Address.create!(
      addressable: customer,
      address_type: "shipping",
      **addr
    )
  end
end

# -----------------------------------------------------------------------------
# Orders with all status combinations
# -----------------------------------------------------------------------------
puts "  Creating orders with various statuses..."

# COMPLETED + PAID orders
order1 = Order.create!(organisation: groceries, customer: groceries_customers["hans@bakery.com"],
                       status: "completed", payment_status: "paid")
OrderItem.create!(order: order1, product: groceries_products["artisan-sourdough-flour"], quantity: 50)
OrderItem.create!(order: order1, product: groceries_products["grass-fed-butter"], quantity: 20)
OrderItem.create!(order: order1, product: groceries_products["organic-honey"], quantity: 10)

order2 = Order.create!(organisation: groceries, customer: groceries_customers["maria@cafe.com"],
                       status: "completed", payment_status: "paid")
OrderItem.create!(order: order2, product: groceries_products["organic-coffee-beans"], quantity: 30)
OrderItem.create!(order: order2, product: groceries_products["fresh-mozzarella"], quantity: 15)

order3 = Order.create!(organisation: groceries, customer: groceries_customers["oliver@greenkitchen.com"],
                       status: "completed", payment_status: "paid")
OrderItem.create!(order: order3, product: groceries_products["fresh-basil"], quantity: 25)
OrderItem.create!(order: order3, product: groceries_products["organic-apples"], quantity: 40)
OrderItem.create!(order: order3, product: groceries_products["organic-lemons"], quantity: 30)

# PROCESSED + PENDING orders
order4 = Order.create!(organisation: groceries, customer: groceries_customers["erik@nordicdelights.com"],
                       status: "processed", payment_status: "pending")
OrderItem.create!(order: order4, product: groceries_products["wild-caught-salmon"], quantity: 20)
OrderItem.create!(order: order4, product: groceries_products["atlantic-shrimp"], quantity: 15)

order5 = Order.create!(organisation: groceries, customer: groceries_customers["sophie@freshandco.com"],
                       status: "processed", payment_status: "pending")
OrderItem.create!(order: order5, product: groceries_products["prime-ribeye-steak"], quantity: 25)
OrderItem.create!(order: order5, product: groceries_products["aged-parmesan"], quantity: 10)
OrderItem.create!(order: order5, product: groceries_products["premium-olive-oil"], quantity: 12)
OrderItem.create!(order: order5, product: groceries_products["balsamic-vinegar"], quantity: 8)

# IN_PROCESS + PENDING orders
order6 = Order.create!(organisation: groceries, customer: groceries_customers["james@urbanbistro.com"],
                       status: "in_process", payment_status: "pending")
OrderItem.create!(order: order6, product: groceries_products["organic-coffee-beans"], quantity: 15)
OrderItem.create!(order: order6, product: groceries_products["whole-wheat-flour"], quantity: 30)

# PROCESSED + FAILED (payment failure scenario)
order7 = Order.create!(organisation: groceries, customer: groceries_customers["anna@sunrisehotel.com"],
                       status: "processed", payment_status: "failed")
OrderItem.create!(order: order7, product: groceries_products["wild-caught-salmon"], quantity: 50)
OrderItem.create!(order: order7, product: groceries_products["prime-ribeye-steak"], quantity: 40)
OrderItem.create!(order: order7, product: groceries_products["aged-parmesan"], quantity: 20)

# COMPLETED + REFUNDED (refund scenario)
order8 = Order.create!(organisation: groceries, customer: groceries_customers["michael@cornerdeli.com"],
                       status: "completed", payment_status: "refunded")
OrderItem.create!(order: order8, product: groceries_products["fresh-mozzarella"], quantity: 10)

puts "  Created #{groceries.orders.count} orders with #{OrderItem.where(order: groceries.orders).count} items"

# =============================================================================
# ORGANISATION 2: Screw Market (Secondary org for multi-tenant testing)
# =============================================================================
puts "\n" + "=" * 70
puts "ORGANISATION 2: Screw Market"
puts "=" * 70

screws = Organisation.create!(
  name: "Screw Market",
  billing_email: "billing@screwmarket.com"
)

Address.create!(
  addressable: screws,
  address_type: "billing",
  street_name: "999 Industrial Parkway",
  postal_code: "07001",
  city: "Newark",
  country: "United States"
)

# -----------------------------------------------------------------------------
# Members
# -----------------------------------------------------------------------------
puts "  Creating members..."

# OWNER for Screw Market only
screws_owner = Member.create!(
  email: "owner@screws.com",
  password: "123123",
  first_name: "Steve",
  last_name: "Screwdriver"
)
OrgMember.create!(
  organisation: screws,
  member: screws_owner,
  role: "owner",
  active: true,
  joined_at: 2.years.ago
)

# SHARED MEMBER - belongs to BOTH organizations (multi-org access testing)
shared_member = Member.create!(
  email: "shared@test.com",
  password: "123123",
  first_name: "Sarah",
  last_name: "Multiorg"
)
OrgMember.create!(
  organisation: groceries,
  member: shared_member,
  role: "admin",
  active: true,
  joined_at: 4.months.ago
)
OrgMember.create!(
  organisation: screws,
  member: shared_member,
  role: "member",
  active: true,
  joined_at: 2.months.ago
)

# -----------------------------------------------------------------------------
# Categories & Products
# -----------------------------------------------------------------------------
puts "  Creating categories and products..."

screws_categories = {
  "Screws" => Category.create!(name: "Screws", organisation: screws),
  "Bolts" => Category.create!(name: "Bolts", organisation: screws),
  "Nuts" => Category.create!(name: "Nuts", organisation: screws)
}

screws_products_data = [
  { name: "Wood Screws #8", slug: "wood-screws-8", sku: "SCR-WD-008", desc: "Standard wood screws, #8 gauge", cat: "Screws", price: 599, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934102/wood_screw_lixwxw.avif" },
  { name: "Wood Screws #10", slug: "wood-screws-10", sku: "SCR-WD-010", desc: "Standard wood screws, #10 gauge", cat: "Screws", price: 699, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934100/10gaugue_wood_screw_w3evqf.webp" },
  { name: "Drywall Screws", slug: "drywall-screws", sku: "SCR-DW-001", desc: "Fine thread drywall screws", cat: "Screws", price: 499, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934100/drywall_screw_zvdrey.webp" },
  { name: "Machine Screws", slug: "machine-screws", sku: "SCR-MC-001", desc: "Precision machine screws", cat: "Screws", price: 899, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934102/machine_screw_bcfzjk.webp" },
  { name: "Deck Screws", slug: "deck-screws", sku: "SCR-DK-001", desc: "Weather-resistant deck screws", cat: "Screws", price: 1299, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934100/deck_screw_operpd.avif" },
  { name: "Hex Bolts", slug: "hex-bolts", sku: "BLT-HX-001", desc: "Standard hex head bolts", cat: "Bolts", price: 799, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934100/hex_bolt_iy1h4b.webp" },
  { name: "Carriage Bolts", slug: "carriage-bolts", sku: "BLT-CR-001", desc: "Round head carriage bolts", cat: "Bolts", price: 899, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934100/carriage_bolts_gm1afj.webp" },
  { name: "Lag Bolts", slug: "lag-bolts", sku: "BLT-LG-001", desc: "Heavy duty lag bolts", cat: "Bolts", price: 1199, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934101/lag_bolts_srvpoq.webp" },
  { name: "Hex Nuts", slug: "hex-nuts", sku: "NUT-HX-001", desc: "Standard hex nuts", cat: "Nuts", price: 299, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934100/hex_nuts_jpnuq7.jpg" },
  { name: "Lock Nuts", slug: "lock-nuts", sku: "NUT-LK-001", desc: "Nylon insert lock nuts", cat: "Nuts", price: 399, image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1764934102/lock_nuts_dca4zn.jpg" }
]

screws_products = {}
screws_products_data.each do |data|
  product = Product.create!(
    organisation: screws,
    name: data[:name],
    slug: data[:slug],
    sku: data[:sku],
    description: data[:desc],
    category: screws_categories[data[:cat]],
    unit_price: data[:price],
    unit_description: "box of 100",
    min_quantity: 1,
    min_quantity_type: "box",
    available: true
  )
  screws_products[data[:slug]] = product

  # Attach product photo from URL
  file = URI.open(data[:image_url])
  product.photo.attach(io: file, filename: "#{data[:slug]}.jpg", content_type: "image/jpeg")
end
puts "  Attached photos to #{screws_products.count} products"

# -----------------------------------------------------------------------------
# Customers (including SAME EMAIL as Groceries org - tests scoped uniqueness)
# -----------------------------------------------------------------------------
puts "  Creating customers (including same email as Groceries org)..."

screws_customers_data = [
  { company: "Build It Right Construction", contact: "John Builder", email: "john@builditright.com" },
  { company: "Home Depot Pro", contact: "Mary Contractor", email: "mary@homedepotpro.com" },
  { company: "Fix Everything LLC", contact: "Bob Fixer", email: "bob@fixeverything.com" },
  { company: "Carpenter's Choice", contact: "Carl Carpenter", email: "carl@carpenterschoice.com" },
  { company: "DIY Warehouse", contact: "Diana DIY", email: "diana@diywarehouse.com" },
  # SAME EMAIL as Groceries customer (tests scoped email uniqueness!)
  { company: "Hans' Hardware Division", contact: "Hans Hansensen", email: "hans@bakery.com" }
]

screws_customers = {}
screws_customers_data.each do |data|
  customer = Customer.create!(
    organisation: screws,
    company_name: data[:company],
    contact_name: data[:contact],
    email: data[:email],
    password: "123123",
    active: true
  )
  screws_customers[data[:email]] = customer

  Address.create!(
    addressable: customer,
    address_type: "billing",
    street_name: "#{rand(100..999)} Industrial Ave",
    postal_code: "0700#{rand(1..9)}",
    city: "Newark",
    country: "United States"
  )
  Address.create!(
    addressable: customer,
    address_type: "shipping",
    street_name: "#{rand(100..999)} Warehouse Blvd",
    postal_code: "0700#{rand(1..9)}",
    city: "Newark",
    country: "United States"
  )
end

# -----------------------------------------------------------------------------
# Orders
# -----------------------------------------------------------------------------
puts "  Creating orders..."

order_s1 = Order.create!(organisation: screws, customer: screws_customers["john@builditright.com"],
                         status: "completed", payment_status: "paid")
OrderItem.create!(order: order_s1, product: screws_products["wood-screws-8"], quantity: 50)
OrderItem.create!(order: order_s1, product: screws_products["hex-bolts"], quantity: 30)

order_s2 = Order.create!(organisation: screws, customer: screws_customers["mary@homedepotpro.com"],
                         status: "in_process", payment_status: "pending")
OrderItem.create!(order: order_s2, product: screws_products["drywall-screws"], quantity: 100)
OrderItem.create!(order: order_s2, product: screws_products["deck-screws"], quantity: 75)

# Order from the shared-email customer (Hans in Screws org)
order_s3 = Order.create!(organisation: screws, customer: screws_customers["hans@bakery.com"],
                         status: "processed", payment_status: "pending")
OrderItem.create!(order: order_s3, product: screws_products["machine-screws"], quantity: 200)
OrderItem.create!(order: order_s3, product: screws_products["lock-nuts"], quantity: 200)

puts "  Created #{screws.orders.count} orders with #{OrderItem.where(order: screws.orders).count} items"

# =============================================================================
# ORGANISATION 3: Empty Startup (Edge case testing - no data)
# =============================================================================
puts "\n" + "=" * 70
puts "ORGANISATION 3: Empty Startup (edge case)"
puts "=" * 70

empty_org = Organisation.create!(
  name: "Empty Startup",
  billing_email: "hello@emptystartup.com"
)

lonely_member = Member.create!(
  email: "lonely@test.com",
  password: "123123",
  first_name: "Luna",
  last_name: "Lonely"
)
OrgMember.create!(
  organisation: empty_org,
  member: lonely_member,
  role: "owner",
  active: true,
  joined_at: 1.week.ago
)

puts "  Created empty org with 1 member, 0 customers, 0 products"

# =============================================================================
# ORGANISATION 4: Kubrix (Construction Material Supplier)
# =============================================================================
puts "\n" + "=" * 70
puts "ORGANISATION 4: Kubrix (Construction Materials)"
puts "=" * 70

kubrix = Organisation.create!(
  name: "Kubrix",
  billing_email: "billing@kubrix.ch"
)

Address.create!(
  addressable: kubrix,
  address_type: "billing",
  street_name: "Industriestrasse 12",
  postal_code: "8304",
  city: "Wallisellen",
  country: "Switzerland"
)

# -----------------------------------------------------------------------------
# Members
# -----------------------------------------------------------------------------
puts "  Creating members..."

# ADMIN - Backoffice administrator
kubrix_admin = Member.create!(
  email: "admin@kubrix.ch",
  password: "123123",
  first_name: "Marco",
  last_name: "Baumann"
)
OrgMember.create!(
  organisation: kubrix,
  member: kubrix_admin,
  role: "admin",
  active: true,
  joined_at: 1.year.ago
)

# OWNER - Full access
kubrix_owner = Member.create!(
  email: "owner@kubrix.ch",
  password: "123123",
  first_name: "Stefan",
  last_name: "Mueller"
)
OrgMember.create!(
  organisation: kubrix,
  member: kubrix_owner,
  role: "owner",
  active: true,
  joined_at: 2.years.ago
)

# -----------------------------------------------------------------------------
# Categories (based on Kubrix product range)
# -----------------------------------------------------------------------------
puts "  Creating categories..."

kubrix_categories = {}
[
  "Clay Bricks",
  "Calcium Silicate Bricks",
  "Thermal Insulation Bricks",
  "Clay Building Materials",
  "Masonry Accessories",
  "System Solutions"
].each do |name|
  kubrix_categories[name] = Category.create!(name: name, organisation: kubrix)
end

# -----------------------------------------------------------------------------
# Products (realistic B2B construction materials)
# -----------------------------------------------------------------------------
puts "  Creating products..."

kubrix_products_data = [
  # Clay Bricks (prices per m², ~48 bricks/m² for NF format)
  # Using Lorem Picsum for reliable placeholder images
  { name: "Modular Brick NF", slug: "modular-brick-nf", sku: "KBX-CB-001",
    description: "240x115x71mm, 2.1kg/unit. High compressive strength for load-bearing masonry. 48 units/m².",
    category: "Clay Bricks", unit_price: 4200, unit_description: "m²", min_qDFty: 10, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195722/modular_brick_a2w0zt.jpg" },
  { name: "Modular Brick 2DF", slug: "modular-brick-2df", sku: "KBX-CB-002",
    description: "240x115x113mm, 3.8kg/unit. Double format for efficient masonry. 32 units/m².",
    category: "Clay Bricks", unit_price: 5800, unit_description: "m²", min_qty: 10, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195722/Modular_Brick_2DF_me68sr.jpg" },
  { name: "PESO Hollow Brick", slug: "peso-hollow-brick", sku: "KBX-CB-003",
    description: "300x200x238mm, 12.5kg/unit. Vertical perforations for insulation. 16 units/m².",
    category: "Clay Bricks", unit_price: 6500, unit_description: "m²", min_qty: 5, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195723/PESO_Hollow_Brick_xlgae2.webp" },
  { name: "Clinker Solid Brick", slug: "clinker-solid-brick", sku: "KBX-CB-004",
    description: "240x115x71mm, 2.4kg/unit. Premium facade clinker, frost resistant. 48 units/m².",
    category: "Clay Bricks", unit_price: 8900, unit_description: "m²", min_qty: 15, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195718/Clinker_Solid_Brick_zwkrdg.jpg" },

  # Calcium Silicate Bricks (prices per m²)
  { name: "CS Brick NF 20-2.0", slug: "cs-brick-nf-20", sku: "KBX-CS-001",
    description: "240x115x71mm, 2.8kg/unit. Compressive strength 20 N/mm², density 2.0. 48 units/m².",
    category: "Calcium Silicate Bricks", unit_price: 3800, unit_description: "m²", min_qty: 10, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195719/CS_Brick_NF_20-2_xeqyya.png" },
  { name: "CS Brick 3DF 12-1.8", slug: "cs-brick-3df-12", sku: "KBX-CS-002",
    description: "240x175x113mm, 5.2kg/unit. Triple format for rapid construction. 24 units/m².",
    category: "Calcium Silicate Bricks", unit_price: 4500, unit_description: "m²", min_qty: 10, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195719/CS_Brick_3DF_12-1.8_yvdbf6.jpg" },
  { name: "PROFILA CS Precision Block", slug: "profila-cs-precision-block", sku: "KBX-CS-003",
    description: "498x175x248mm, 18.5kg/unit. For thin-bed mortar, highest accuracy. 8 units/m².",
    category: "Calcium Silicate Bricks", unit_price: 5200, unit_description: "m²", min_qty: 8, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195724/PROFILA_CS_Precision_Block_tjoicp.jpg" },
  { name: "CS Lintel Elements", slug: "cs-lintel-elements", sku: "KBX-CS-004",
    description: "1000x115x238mm, 42kg/unit. Prefab lintel for openings up to 1.5m span.",
    category: "Calcium Silicate Bricks", unit_price: 12500, unit_description: "m²", min_qty: 2, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195721/CS_Lintel_Elements_bg00mc.png" },

  # Thermal Insulation Bricks (prices per m²)
  { name: "KISmur Thermal Block", slug: "kismur-thermal-block", sku: "KBX-TI-001",
    description: "365x248x249mm, 14.2kg/unit. U-value 0.21 W/m²K, single-leaf construction. 8 units/m².",
    category: "Thermal Insulation Bricks", unit_price: 7800, unit_description: "m²", min_qty: 5, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195721/KISmur_Thermal_Block_m9k0l0.jpg" },
  { name: "Poroton T7 Insulation Brick", slug: "poroton-t7-brick", sku: "KBX-TI-002",
    description: "425x248x249mm, 15.8kg/unit. Mineral wool filled, U-value 0.18 W/m²K. 8 units/m².",
    category: "Thermal Insulation Bricks", unit_price: 9500, unit_description: "m²", min_qty: 5, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195723/Poroton_T7_Insulation_Brick_sc5nzv.jpg" },
  { name: "Thermoblock Plus", slug: "thermoblock-plus", sku: "KBX-TI-003",
    description: "490x300x249mm, 18.5kg/unit. Passive house grade, U-value 0.15 W/m²K. 8 units/m².",
    category: "Thermal Insulation Bricks", unit_price: 12500, unit_description: "m²", min_qty: 5, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195726/Thermoblock_Plus_hi7tjq.jpg" },

  # Clay Building Materials (prices per m²)
  { name: "Argila Natural Clay Brick NF", slug: "argila-clay-brick-nf", sku: "KBX-CL-001",
    description: "240x115x71mm, 2.0kg/unit. Swiss clay, ecological construction. 48 units/m².",
    category: "Clay Building Materials", unit_price: 5500, unit_description: "m²", min_qty: 10, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195718/Argila_Natural_Clay_Brick_NF_ef322z.jpg" },
  { name: "Argila Clay Board", slug: "argila-clay-board", sku: "KBX-CL-002",
    description: "625x312x22mm, 8.5kg/unit. Interior walls, natural humidity regulation. 5.1 units/m².",
    category: "Clay Building Materials", unit_price: 4200, unit_description: "m²", min_qty: 5, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195718/Argila_Clay_Board_zznaye.webp" },
  { name: "Green Clay Brick (Unfired)", slug: "green-clay-brick", sku: "KBX-CL-003",
    description: "240x115x71mm, 1.9kg/unit. Unfired for natural climate regulation. 48 units/m².",
    category: "Clay Building Materials", unit_price: 4800, unit_description: "m²", min_qty: 10, available: false,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195720/Green_Clay_Brick_Unfired_gvs6vk.jpg" },

  # Masonry Accessories (various units, but min_qty in m² equivalent where applicable)
  { name: "Lintel Board Type A", slug: "lintel-board-type-a", sku: "KBX-MA-001",
    description: "2000x200x27mm, 4.2kg/unit. Reusable formwork for lintels. Coverage: 0.4m² per unit.",
    category: "Masonry Accessories", unit_price: 11500, unit_description: "m²", min_qty: 1, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195721/Lintel_Board_Type_A_ir4kho.webp" },
  { name: "Concrete Lintel B25", slug: "concrete-lintel-b25", sku: "KBX-MA-002",
    description: "1500x115x175mm, 58kg/unit. Reinforced for openings up to 2m span.",
    category: "Masonry Accessories", unit_price: 8500, unit_description: "m²", min_qty: 1, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195719/Concrete_Lintel_B25_x1u0qa.png" },
  { name: "Thin-Bed Mortar Premium", slug: "thin-bed-mortar-premium", sku: "KBX-MA-003",
    description: "25kg bag covers ~8m². High-strength adhesive mortar for precision blocks.",
    category: "Masonry Accessories", unit_price: 350, unit_description: "m²", min_qty: 8, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195727/Thin-Bed_Mortar_Premium_ujydoh.jpg" },
  { name: "Stainless Steel Wall Ties", slug: "stainless-steel-wall-ties", sku: "KBX-MA-004",
    description: "200mm length, 0.015kg/unit. Corrosion resistant, 5 ties per m² required.",
    category: "Masonry Accessories", unit_price: 150, unit_description: "m²", min_qty: 10, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195725/Stainless_Steel_Wall_Ties_ugbtce.webp" },
  { name: "Ring Beam Reinforcement", slug: "ring-beam-reinforcement", sku: "KBX-MA-005",
    description: "6m length, 12kg/set. Prefab cages for ring beams, 150x150mm cross-section.",
    category: "Masonry Accessories", unit_price: 950, unit_description: "m²", min_qty: 6, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195724/Ring_Beam_Reinforcement_fmjcwk.jpg" },

  # System Solutions (prices per m²)
  { name: "KISmur Complete System", slug: "kismur-complete-system", sku: "KBX-SS-001",
    description: "All-in-one: thermal blocks, mortar, ties, lintels. U-value 0.21 W/m²K. ~285kg/m².",
    category: "System Solutions", unit_price: 9500, unit_description: "m²", min_qty: 20, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195721/KISmur_Complete_System_kiqnoy.webp" },
  { name: "Sound Insulation System SS1", slug: "sound-insulation-system-ss1", sku: "KBX-SS-002",
    description: "Complete partition wall system. Rw 58 dB rated, 175mm thickness. ~220kg/m².",
    category: "System Solutions", unit_price: 6800, unit_description: "m²", min_qty: 15, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195725/Sound_Insulation_System_SS1_knf6mn.jpg" },
  { name: "Fire Protection System F90", slug: "fire-protection-system-f90", sku: "KBX-SS-003",
    description: "Certified F90 system, 200mm thickness. Fire resistant 90 minutes. ~240kg/m².",
    category: "System Solutions", unit_price: 7500, unit_description: "m²", min_qty: 15, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195720/Fire_Protection_System_F90_dvbpnx.png" }
]

kubrix_products = {}
kubrix_products_data.each do |data|
  product = Product.create!(
    organisation: kubrix,
    name: data[:name],
    slug: data[:slug],
    sku: data[:sku],
    description: data[:description],
    category: kubrix_categories[data[:category]],
    unit_price: data[:unit_price],
    unit_description: data[:unit_description],
    min_quantity: data[:min_qty],
    min_quantity_type: "m²",
    available: data[:available]
  )
  kubrix_products[data[:slug]] = product

  # Attach product photo from Unsplash
  if data[:image_url]
    file = URI.open(data[:image_url])
    product.photo.attach(io: file, filename: "#{data[:slug]}.jpg", content_type: "image/jpeg")
  end
end
puts "  Attached photos to #{kubrix_products.count} products"

# -----------------------------------------------------------------------------
# Customers (Construction firms as B2B clients)
# -----------------------------------------------------------------------------
puts "  Creating customers (construction firms)..."

kubrix_customers_data = [
  {
    company_name: "Frei Construction AG",
    contact_name: "Thomas Frei",
    email: "thomas@frei-bau.ch",
    active: true,
    billing: { street_name: "Baustrasse 45", postal_code: "8001", city: "Zurich", country: "Switzerland" },
    shipping: [
      { street_name: "Baustrasse 45 (Office)", postal_code: "8001", city: "Zurich", country: "Switzerland" },
      { street_name: "Industrieweg 12 (Warehouse)", postal_code: "8050", city: "Zurich-Oerlikon", country: "Switzerland" }
    ]
  },
  {
    company_name: "Keller & Son Building Co.",
    contact_name: "Beat Keller",
    email: "beat@keller-building.ch",
    active: true,
    billing: { street_name: "Werkstrasse 8", postal_code: "8200", city: "Schaffhausen", country: "Switzerland" },
    shipping: [
      { street_name: "Werkstrasse 8", postal_code: "8200", city: "Schaffhausen", country: "Switzerland" }
    ]
  },
  {
    company_name: "Alpine General Contractors",
    contact_name: "Martin Huber",
    email: "huber@alpine-contractors.ch",
    active: true,
    billing: { street_name: "Bergstrasse 22", postal_code: "6004", city: "Lucerne", country: "Switzerland" },
    shipping: [
      { street_name: "Bergstrasse 22 (HQ)", postal_code: "6004", city: "Lucerne", country: "Switzerland" },
      { street_name: "Industrial Park 5 (East Depot)", postal_code: "6340", city: "Baar", country: "Switzerland" },
      { street_name: "Commercial Zone 18 (West Depot)", postal_code: "6210", city: "Sursee", country: "Switzerland" }
    ]
  },
  {
    company_name: "Swiss Residential Builders AG",
    contact_name: "Sandra Meier",
    email: "meier@swiss-residential.ch",
    active: true,
    billing: { street_name: "Office Park 3", postal_code: "3001", city: "Bern", country: "Switzerland" },
    shipping: [
      { street_name: "Warehouse Street 15", postal_code: "3018", city: "Bern-Bumpliz", country: "Switzerland" }
    ]
  },
  {
    company_name: "Zurich Structural Works GmbH",
    contact_name: "Peter Brunner",
    email: "brunner@zurich-structural.ch",
    active: true,
    billing: { street_name: "Concrete Way 7", postal_code: "8047", city: "Zurich-Albisrieden", country: "Switzerland" },
    shipping: [
      { street_name: "Concrete Way 7", postal_code: "8047", city: "Zurich-Albisrieden", country: "Switzerland" }
    ]
  },
  {
    company_name: "Ticino Construction SA",
    contact_name: "Marco Bentivoglio",
    email: "bentivoglio@ticino-construction.ch",
    active: true,
    billing: { street_name: "Via Industria 28", postal_code: "6900", city: "Lugano", country: "Switzerland" },
    shipping: [
      { street_name: "Via Industria 28", postal_code: "6900", city: "Lugano", country: "Switzerland" },
      { street_name: "Via Artigiani 5", postal_code: "6512", city: "Giubiasco", country: "Switzerland" }
    ]
  },
  {
    company_name: "Western Swiss Builders SA",
    contact_name: "Jean-Pierre Rochat",
    email: "rochat@western-swiss-builders.ch",
    active: true,
    billing: { street_name: "Route de Lausanne 50", postal_code: "1203", city: "Geneva", country: "Switzerland" },
    shipping: [
      { street_name: "Industrial Zone 12", postal_code: "1227", city: "Carouge", country: "Switzerland" }
    ]
  },
  # INACTIVE customer
  {
    company_name: "Old Building Renovation AG (INACTIVE)",
    contact_name: "Hans Mueller",
    email: "mueller@old-building-renovation.ch",
    active: false,
    billing: { street_name: "Closed Street 1", postal_code: "8000", city: "Zurich", country: "Switzerland" },
    shipping: []
  }
]

kubrix_customers = {}
kubrix_customers_data.each do |data|
  customer = Customer.create!(
    organisation: kubrix,
    company_name: data[:company_name],
    contact_name: data[:contact_name],
    email: data[:email],
    password: "123123",
    active: data[:active]
  )
  kubrix_customers[data[:email]] = customer

  # Billing address
  Address.create!(
    addressable: customer,
    address_type: "billing",
    **data[:billing]
  )

  # Shipping addresses
  data[:shipping].each do |addr|
    Address.create!(
      addressable: customer,
      address_type: "shipping",
      **addr
    )
  end
end

# -----------------------------------------------------------------------------
# Orders (typical B2B construction material orders)
# -----------------------------------------------------------------------------
puts "  Creating orders..."

# COMPLETED + PAID - Large residential project order
order_k1 = Order.create!(organisation: kubrix, customer: kubrix_customers["thomas@frei-bau.ch"],
                         status: "completed", payment_status: "paid", placed_at: Time.current)
OrderItem.create!(order: order_k1, product: kubrix_products["modular-brick-2df"], quantity: 15)
OrderItem.create!(order: order_k1, product: kubrix_products["cs-brick-nf-20"], quantity: 20)
OrderItem.create!(order: order_k1, product: kubrix_products["thin-bed-mortar-premium"], quantity: 100)
OrderItem.create!(order: order_k1, product: kubrix_products["concrete-lintel-b25"], quantity: 8)

# COMPLETED + PAID - Eco building project
order_k2 = Order.create!(organisation: kubrix, customer: kubrix_customers["huber@alpine-contractors.ch"],
                         status: "completed", payment_status: "paid", placed_at: Time.current)
OrderItem.create!(order: order_k2, product: kubrix_products["argila-clay-brick-nf"], quantity: 25)
OrderItem.create!(order: order_k2, product: kubrix_products["argila-clay-board"], quantity: 40)
OrderItem.create!(order: order_k2, product: kubrix_products["kismur-thermal-block"], quantity: 30)

# PROCESSED + PENDING - Commercial building order
order_k3 = Order.create!(organisation: kubrix, customer: kubrix_customers["meier@swiss-residential.ch"],
                         status: "processed", payment_status: "pending", placed_at: Time.current)
OrderItem.create!(order: order_k3, product: kubrix_products["profila-cs-precision-block"], quantity: 50)
OrderItem.create!(order: order_k3, product: kubrix_products["fire-protection-system-f90"], quantity: 4)
OrderItem.create!(order: order_k3, product: kubrix_products["cs-lintel-elements"], quantity: 12)

# IN_PROCESS + PENDING - Apartment complex order
order_k4 = Order.create!(organisation: kubrix, customer: kubrix_customers["beat@keller-building.ch"],
                         status: "in_process", payment_status: "pending")
OrderItem.create!(order: order_k4, product: kubrix_products["thermoblock-plus"], quantity: 60)
OrderItem.create!(order: order_k4, product: kubrix_products["sound-insulation-system-ss1"], quantity: 8)
OrderItem.create!(order: order_k4, product: kubrix_products["stainless-steel-wall-ties"], quantity: 50)

# PROCESSED + PAID - Small contractor order
order_k5 = Order.create!(organisation: kubrix, customer: kubrix_customers["brunner@zurich-structural.ch"],
                         status: "processed", payment_status: "paid", placed_at: Time.current)
OrderItem.create!(order: order_k5, product: kubrix_products["peso-hollow-brick"], quantity: 10)
OrderItem.create!(order: order_k5, product: kubrix_products["lintel-board-type-a"], quantity: 6)
OrderItem.create!(order: order_k5, product: kubrix_products["ring-beam-reinforcement"], quantity: 20)

# COMPLETED + PAID - Premium facade project
order_k6 = Order.create!(organisation: kubrix, customer: kubrix_customers["bentivoglio@ticino-construction.ch"],
                         status: "completed", payment_status: "paid", placed_at: Time.current)
OrderItem.create!(order: order_k6, product: kubrix_products["clinker-solid-brick"], quantity: 40)
OrderItem.create!(order: order_k6, product: kubrix_products["kismur-complete-system"], quantity: 2)

# IN_PROCESS + PENDING - New construction project
order_k7 = Order.create!(organisation: kubrix, customer: kubrix_customers["rochat@western-swiss-builders.ch"],
                         status: "in_process", payment_status: "pending")
OrderItem.create!(order: order_k7, product: kubrix_products["poroton-t7-brick"], quantity: 35)
OrderItem.create!(order: order_k7, product: kubrix_products["modular-brick-nf"], quantity: 25)

puts "  Created #{kubrix.orders.count} orders with #{OrderItem.where(order: kubrix.orders).count} items"

# =============================================================================
# SUMMARY
# =============================================================================
puts "\n" + "=" * 70
puts "SEED COMPLETE!"
puts "=" * 70

puts "\n--- STATISTICS ---"
puts "Organisations:  #{Organisation.count}"
puts "Members:        #{Member.count}"
puts "OrgMembers:     #{OrgMember.count}"
puts "Customers:      #{Customer.count}"
puts "Categories:     #{Category.count}"
puts "Products:       #{Product.count}"
puts "Orders:         #{Order.count}"
puts "OrderItems:     #{OrderItem.count}"
puts "Addresses:      #{Address.count}"

puts "\n" + "=" * 70
puts "TEST ACCOUNTS (all passwords: 123123)"
puts "=" * 70

puts "\nMEMBERS (Back Office Login):"
puts "-" * 40
puts "B2B Groceries:"
puts "  owner@groceries.com     [owner]  - Full access"
puts "  admin@groceries.com     [admin]  - Admin access"
puts "  member@groceries.com    [member] - Limited access"
puts "  inactive@groceries.com  [admin]  - INACTIVE (denied)"
puts ""
puts "Screw Market:"
puts "  owner@screws.com        [owner]  - Full access"
puts ""
puts "Kubrix (Construction Materials):"
puts "  owner@kubrix.ch         [owner]  - Full access"
puts "  admin@kubrix.ch         [admin]  - Admin access (backoffice)"
puts ""
puts "Multi-Org (belongs to BOTH orgs):"
puts "  shared@test.com         [admin in Groceries, member in Screws]"
puts ""
puts "Empty Org (edge case):"
puts "  lonely@test.com         [owner]  - No customers/products"

puts "\nCUSTOMERS (Customer Portal Login):"
puts "-" * 40
puts "B2B Groceries:"
puts "  hans@bakery.com, maria@cafe.com, oliver@greenkitchen.com, etc."
puts "  closed@kitchen.com (INACTIVE - denied)"
puts ""
puts "Screw Market:"
puts "  john@builditright.com, mary@homedepotpro.com, etc."
puts "  hans@bakery.com (SAME EMAIL, different org - tests scoped uniqueness!)"
puts ""
puts "Kubrix (Construction Materials):"
puts "  thomas@frei-bau.ch, beat@keller-building.ch, huber@alpine-contractors.ch, etc."
puts "  mueller@old-building-renovation.ch (INACTIVE - denied)"

puts "\n" + "=" * 70
puts "TEST SCENARIOS"
puts "=" * 70

puts "\n1. ROLE-BASED ACCESS:"
puts "   - owner@groceries.com should have full CRUD on everything"
puts "   - member@groceries.com should have limited access"
puts "   - Compare behavior between roles"

puts "\n2. MULTI-ORG ACCESS:"
puts "   - shared@test.com can access BOTH orgs"
puts "   - Test organization switching in UI"
puts "   - Verify data isolation between orgs"

puts "\n3. INACTIVE USER DENIAL:"
puts "   - inactive@groceries.com should be denied login/access"
puts "   - closed@kitchen.com (customer) should be denied"

puts "\n4. SCOPED EMAIL UNIQUENESS:"
puts "   - hans@bakery.com exists in BOTH orgs as separate accounts"
puts "   - Login to each org's portal with same email, different context"

puts "\n5. ORGANIZATION ISOLATION:"
puts "   - owner@screws.com should NOT see Groceries data"
puts "   - Verify products/customers/orders are isolated"

puts "\n6. EMPTY ORG EDGE CASE:"
puts "   - lonely@test.com sees empty lists (no errors)"
puts "   - Test UI handles zero-state gracefully"

puts "\n7. ORDER STATUS COVERAGE:"
puts "   - Completed + Paid: 4 orders"
puts "   - Processed + Pending: 3 orders"
puts "   - In Process + Pending: 2 orders"
puts "   - Processed + Failed: 1 order"
puts "   - Completed + Refunded: 1 order"

puts "\n8. ADDRESS TESTING:"
puts "   - Customers with 1, 2, or 3 shipping addresses"
puts "   - All have 1 billing address"
puts "   - Test address selection in order flow"

puts "\n" + "=" * 70
