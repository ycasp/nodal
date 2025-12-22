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
# ORGANISATION: Kubrix (Construction Material Supplier)
# =============================================================================
puts "\n" + "=" * 70
puts "ORGANISATION: Kubrix (Construction Materials)"
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

# Theather SEEED - Ayusha
ayusha_kubrix = Member.create!(
  email: "ayusha.kubrix@gmail.com",
  password: "123123",
  first_name: "Ayusha",
  last_name: "Maharjan"
)
OrgMember.create!(
  organisation: kubrix,
  member: ayusha_kubrix,
  role: "member",
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
    category: "Masonry Accessories", unit_price: 350, unit_description: "bag", min_qty: 1, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195727/Thin-Bed_Mortar_Premium_ujydoh.jpg" },
  { name: "Stainless Steel Wall Ties", slug: "stainless-steel-wall-ties", sku: "KBX-MA-004",
    description: "200mm length, 0.015kg/unit. Corrosion resistant, 5 ties per m² required.",
    category: "Masonry Accessories", unit_price: 150, unit_description: "5 ties", min_qty: 50, available: true,
    image_url: "https://res.cloudinary.com/dratqqhaz/image/upload/v1765195725/Stainless_Steel_Wall_Ties_ugbtce.webp" },
  { name: "Ring Beam Reinforcement", slug: "ring-beam-reinforcement", sku: "KBX-MA-005",
    description: "6m length, 12kg/set. Prefab cages for ring beams, 150x150mm cross-section.",
    category: "Masonry Accessories", unit_price: 115, unit_description: "piece", min_qty: 10, available: true,
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
  {
    company_name: "Core Built GmbH",
    contact_name: "Chris Petion",
    email: "chris.corebuilt@gmail.com",
    active: true,
    billing: { street_name: "Castlehofstreet 15", postal_code: "8400", city: "Winterthur", country: "Switzerland" },
    shipping: [
      { street_name: "Stygstreet 10", postal_code: "8462", city: "Rheinau", country: "Switzerland" }
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
puts "Kubrix:"
puts "  owner@kubrix.ch         [owner]  - Full access"
puts "  admin@kubrix.ch         [admin]  - Admin access"

puts "\nCUSTOMERS (Customer Portal Login):"
puts "-" * 40
puts "Kubrix:"
puts "  thomas@frei-bau.ch, beat@keller-building.ch, huber@alpine-contractors.ch, etc."
puts "  mueller@old-building-renovation.ch (INACTIVE - denied)"

puts "\n" + "=" * 70
