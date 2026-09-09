require "test_helper"

class Bo::ProductsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organisation = Organisation.create!(name: "Products Catalog Org", currency: "EUR")
    @admin = Member.create!(email: "products-admin@example.com", password: "password123",
                            first_name: "Ana", last_name: "Admin")
    @organisation.org_members.create!(member: @admin, role: "owner", active: true)
    sign_in @admin
  end

  # Regression guard: the catalog modals/partials were parameterized so the
  # sales-rep page can reuse them. The admin flow must keep working with the
  # default (products-scoped) URLs when no locals are passed.
  test "admin products index renders the catalog modals" do
    get bo_products_path(org_slug: @organisation.slug)
    assert_response :success
  end

  test "admin catalog selection partial renders" do
    get catalog_selection_bo_products_path(org_slug: @organisation.slug)
    assert_response :success
  end
end
