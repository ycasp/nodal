# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
require "open-uri"

Product.destroy_all
Category.destroy_all
Member.destroy_all
Customer.destroy_all
Organisation.destroy_all

puts "destroyed all"

comp = Organisation.new(name: "B2B Groceries", billing_email: "b@b.b")
comp.save!

mem = Member.create!(
  email: "n@n.n",
  password: "123123",
  first_name: "John",
  last_name: "Doe"
 )

OrgMember.create!(
  organisation: comp,
  member: mem,
  role: "admin",
  active: true,
  joined_at: Time.current
)

# Create categories
categories = {}
["Beverages", "Oils & Condiments", "Baking", "Dairy", "Seafood", "Fruits", "Vegetables", "Meat"].each do |cat_name|
  cat = Category.create!(name: cat_name, organisation: comp)
  categories[cat_name] = cat
end

puts "Created #{Category.count} categories"

# Product data matching the screenshot design
products_data = [
  {
    name: "Organic Coffee Beans",
    slug: "organic-coffee-beans",
    sku: "COF-ORG-001",
    description: "Premium organic coffee beans, medium roast with rich flavor.",
    category: "Beverages",
    unit_price: 2499,
    unit_description: "lb"
  },
  {
    name: "Premium Olive Oil",
    slug: "premium-olive-oil",
    sku: "OIL-PRE-002",
    description: "Extra virgin olive oil from Mediterranean olives.",
    category: "Oils & Condiments",
    unit_price: 1850,
    unit_description: "L"
  },
  {
    name: "Artisan Sourdough Flour",
    slug: "artisan-sourdough-flour",
    sku: "FLR-SOU-003",
    description: "High-protein flour perfect for artisan bread baking.",
    category: "Baking",
    unit_price: 1299,
    unit_description: "kg"
  },
  {
    name: "Fresh Mozzarella",
    slug: "fresh-mozzarella",
    sku: "CHE-MOZ-004",
    description: "Creamy fresh mozzarella, perfect for salads and pizza.",
    category: "Dairy",
    unit_price: 875,
    unit_description: "kg"
  },
  {
    name: "Grass-Fed Butter",
    slug: "grass-fed-butter",
    sku: "DAI-BUT-005",
    description: "Rich and creamy butter from grass-fed cows.",
    category: "Dairy",
    unit_price: 650,
    unit_description: "lb"
  },
  {
    name: "Wild-Caught Salmon",
    slug: "wild-caught-salmon",
    sku: "SEA-SAL-006",
    description: "Fresh wild-caught Atlantic salmon fillets.",
    category: "Seafood",
    unit_price: 3200,
    unit_description: "lb"
  },
  {
    name: "Organic Apples",
    slug: "organic-apples",
    sku: "FRU-APP-007",
    description: "Fresh, crisp red apples, ideal for snacking or baking.",
    category: "Fruits",
    unit_price: 299,
    unit_description: "lb"
  },
  {
    name: "Aged Parmesan",
    slug: "aged-parmesan",
    sku: "CHE-PAR-008",
    description: "24-month aged Italian Parmigiano-Reggiano cheese.",
    category: "Dairy",
    unit_price: 2499,
    unit_description: "kg"
  },
  {
    name: "Organic Honey",
    slug: "organic-honey",
    sku: "SWT-HON-009",
    description: "Raw organic wildflower honey from local apiaries.",
    category: "Baking",
    unit_price: 1599,
    unit_description: "jar"
  },
  {
    name: "Fresh Basil",
    slug: "fresh-basil",
    sku: "VEG-BAS-010",
    description: "Aromatic fresh basil leaves, hydroponically grown.",
    category: "Vegetables",
    unit_price: 450,
    unit_description: "bunch"
  },
  {
    name: "Prime Ribeye Steak",
    slug: "prime-ribeye-steak",
    sku: "MEA-RIB-011",
    description: "USDA Prime grade ribeye, dry-aged for 21 days.",
    category: "Meat",
    unit_price: 4599,
    unit_description: "lb"
  },
  {
    name: "Balsamic Vinegar",
    slug: "balsamic-vinegar",
    sku: "OIL-BAL-012",
    description: "Aged balsamic vinegar from Modena, Italy.",
    category: "Oils & Condiments",
    unit_price: 2199,
    unit_description: "bottle"
  },
  {
    name: "Organic Lemons",
    slug: "organic-lemons",
    sku: "FRU-LEM-013",
    description: "Fresh organic lemons, perfect for cooking and drinks.",
    category: "Fruits",
    unit_price: 199,
    unit_description: "lb"
  },
  {
    name: "Atlantic Shrimp",
    slug: "atlantic-shrimp",
    sku: "SEA-SHR-014",
    description: "Large wild-caught Atlantic shrimp, shell-on.",
    category: "Seafood",
    unit_price: 2899,
    unit_description: "lb"
  },
  {
    name: "Whole Wheat Flour",
    slug: "whole-wheat-flour",
    sku: "FLR-WHT-015",
    description: "Stone-ground whole wheat flour for healthy baking.",
    category: "Baking",
    unit_price: 899,
    unit_description: "kg"
  }
]

products_data.each do |prod_data|
  Product.create!(
    organisation: comp,
    name: prod_data[:name],
    slug: prod_data[:slug],
    sku: prod_data[:sku],
    description: prod_data[:description],
    category: categories[prod_data[:category]],
    unit_price: prod_data[:unit_price],
    unit_description: prod_data[:unit_description],
    min_quantity: 1,
    min_quantity_type: "unit",
    available: true
  )
end

puts "Created #{Product.count} products"

Customer.create!(
  organisation: comp,
  company_name: "Hans' Bakery",
  contact_name: "Hans Hansensen",
  email: "h@h.h",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "Maria's Café",
  contact_name: "Maria Santos",
  email: "maria@cafe.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "The Green Kitchen",
  contact_name: "Oliver Green",
  email: "oliver@greenkitchen.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "Nordic Delights",
  contact_name: "Erik Lindqvist",
  email: "erik@nordicdelights.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "Fresh & Co Restaurant",
  contact_name: "Sophie Martin",
  email: "sophie@freshandco.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "Urban Bistro",
  contact_name: "James Chen",
  email: "james@urbanbistro.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "Sunrise Hotel",
  contact_name: "Anna Kowalski",
  email: "anna@sunrisehotel.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "The Corner Deli",
  contact_name: "Michael Brown",
  email: "michael@cornerdeli.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "Golden Spoon Catering",
  contact_name: "Isabella Romano",
  email: "isabella@goldenspoon.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "Blue Ocean Fish Bar",
  contact_name: "Thomas Fischer",
  email: "thomas@blueocean.com",
  password: "123123",
  active: true
)

Customer.create!(
  organisation: comp,
  company_name: "Wholesome Eats",
  contact_name: "Emma Wilson",
  email: "emma@wholesomeeats.com",
  password: "123123",
  active: true
)

comp_screws = Organisation.new(name: "Screw Market", billing_email: "s@s.s")
comp_screws.save!

mem_screw = Member.create!(
  email: "s@s.s",
  password: "123123",
  first_name: "Screw",
  last_name: "Master"
)

OrgMember.create!(
  organisation: comp_screws,
  member: mem_screw,
  role: "admin",
  active: true,
  joined_at: Time.current
)

cat_screw = Category.create!(name: "Screws", organisation: comp_screws)

10.times do |i|
  Customer.create!(
    organisation: comp_screws,
    company_name: "Screw Client #{i + 1}",
    contact_name: "Screw Contact #{i + 1}",
    email: "screw#{i + 1}@client.com",
    password: "123123",
    active: true
  )
end

10.times do |i|
  Product.create!(
    organisation: comp_screws,
    name: "Screw Product #{i + 1}",
    slug: "screw-product-#{i + 1}",
    description: "Screw product description #{i + 1}",
    category: cat_screw,
    min_quantity: 1,
    min_quantity_type: "box",
    unit_price: (i + 1) * 0.99,
    unit_description: "box of screws",
    product_attributes: {}
  )
end

puts "no of orgs: #{Organisation.count}, no of cat: #{Category.count}, no of prod: #{Product.count}, no of customers: #{Customer.count}"
