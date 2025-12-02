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

comp = Organisation.new(name: "B2B Groceries", slug: "b2b-groceries", billing_email: "b@b.b")
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

cat = Category.new(name: "Fruits")
cat.organisation = comp
cat.save!

prod = {
    "organisation_id": comp.id,
    "name": "Organic Apples",
    "slug": "organic_apples",
    "description": "Fresh, crisp red apples, ideal for snacking or baking.",
    "category_id": cat.id,
    "min_quantity": 1,
    "min_quantity_type": "pack",  # sold per pack
    "unit_price": 1.99,      # price per pack
    "unit_description": "pack of 4 apples (≈0.5 kg)",
    "product_attributes": {}
  }
product = Product.new(prod)
img = URI.parse("https://cdn.pixabay.com/photo/2016/09/29/08/33/apple-1702316_1280.jpg").open
product.photo.attach(io: img , filename: "apple.jpg", content_type: "image/jpeg")
product.save!

Customer.create!(
  organisation: comp,
  company_name: "Hans' Bakery",
  contact_name: "Hans Hansensen",
  email: "h@h.h",
  password: "123123",
  active: true
)

puts "no of orgs; #{Organisation.count}, no of cat: #{Category.count}, no of prod: #{Product.count}"
