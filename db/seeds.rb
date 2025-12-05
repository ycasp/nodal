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
