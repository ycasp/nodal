require "test_helper"

# The BO mobile hamburger menu (bo/shared/_bo_navbar) hand-duplicates the
# sidebar's link list, so entries silently drift out of sync — "Faltas" was
# missing from it entirely. Below 768px the sidebar is translated off-screen,
# so this dropdown is the ONLY way to navigate: a link missing here is a link
# unreachable on mobile.
class Bo::MobileMenuTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organisation = Organisation.create!(name: "Menu Test Org", currency: "EUR")
    @member = Member.create!(
      email: "menu-test@example.com",
      password: "password123",
      first_name: "Menu",
      last_name: "Tester"
    )
    @organisation.org_members.create!(member: @member, role: "owner", active: true)
    sign_in @member
  end

  # Every main-nav destination the sidebar offers must also be in the dropdown.
  test "mobile menu links to every main sidebar destination" do
    get bo_path(org_slug: @organisation.slug)
    assert_response :success

    menu = css_select(".bo-collapsed-menu .dropdown-menu").first
    assert menu, "expected the mobile hamburger dropdown to render"

    hrefs = menu.css("a").map { |a| a["href"] }.compact
    slug = @organisation.slug

    {
      "dashboard"     => bo_path(org_slug: slug),
      "customers"     => bo_customers_path(org_slug: slug),
      "products"      => bo_products_path(org_slug: slug),
      "categories"    => bo_categories_path(org_slug: slug),
      "attributes"    => bo_product_attributes_path(org_slug: slug),
      "orders"        => bo_orders_path(org_slug: slug),
      "unmet_demands" => bo_unmet_demands_path(org_slug: slug),
      "pricing"       => bo_pricing_path(org_slug: slug)
    }.each do |label, path|
      assert_includes hrefs, path, "mobile menu is missing the #{label} link"
    end
  end

  test "mobile menu shows the open faltas count when there are any" do
    customer = Customer.create!(
      organisation: @organisation,
      company_name: "Falta Co",
      contact_name: "Falta Co",
      email: "falta-co@example.com",
      active: true
    )
    customer_user = customer.customer_users.create!(
      organisation: @organisation,
      email: "buyer@falta-co.example.com",
      contact_name: "Buyer"
    )
    product = Product.create!(organisation: @organisation, name: "Short Item")

    UnmetDemand.create!(
      organisation: @organisation,
      customer: customer,
      customer_user: customer_user,
      product: product,
      requested_quantity: 4,
      reason: "capped",
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )

    get bo_path(org_slug: @organisation.slug)
    assert_response :success

    menu = css_select(".bo-collapsed-menu .dropdown-menu").first
    faltas_link = menu.css("a").find { |a| a["href"] == bo_unmet_demands_path(org_slug: @organisation.slug) }
    assert faltas_link, "expected a Faltas link in the mobile menu"
    assert_equal "1", faltas_link.css(".badge").text.strip
  end
end
