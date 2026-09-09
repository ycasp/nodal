require "application_system_test_case"

# The picker lives inside the page's save form and is driven by Stimulus and a
# turbo-frame, so the things that break it only break in a browser: a nested
# form saving the product on every keystroke, Enter submitting the page, a
# selected product reappearing in the list to add. Request tests cannot see any
# of that.
class RelatedProductsPickerTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  include Warden::Test::Helpers

  setup do
    Warden.test_mode!

    @organisation = Organisation.create!(name: "Picker Org", currency: "EUR")
    @admin = Member.create!(email: "picker-admin@example.com", password: "password123",
                            first_name: "Ana", last_name: "Admin")
    @organisation.org_members.create!(member: @admin, role: "owner", active: true)

    @rings = @organisation.categories.create!(name: "Anéis")
    @product = create_product("Anel Marcassites", category: @rings)
    @sibling = create_product("Anel Prata Azul", category: @rings)
    @far_away = create_product("Pulseira Dourada")

    login_as @admin, scope: :member
  end

  teardown { Warden.test_reset! }

  def create_product(name, category: nil)
    product = @organisation.products.create!(name: name, unit_price: 1000, published: true)
    product.categories << category if category
    product
  end

  def visit_picker
    visit related_products_bo_product_path(org_slug: @organisation.slug, id: @product.id)
    assert_selector "[data-related-products-target='availableItem']", wait: 5
  end

  # The regression this test exists for. The search box used to sit in a nested
  # <form>, which the browser discards — so the input belonged to the page's
  # save form and every keystroke saved the product.
  #
  # Waiting for the results to come back first is what makes this a guard: the
  # assertions below are all negative, and a negative assertion passes instantly
  # against a page that has not had time to go wrong yet.
  test "typing in the search box does not save the product" do
    visit_picker

    fill_in_search "Pulseira"
    wait_for_search_results

    assert_current_path related_products_bo_product_path(org_slug: @organisation.slug, id: @product.id)
    assert_no_selector ".alert", text: I18n.t("bo.products.related.updated")
    assert_equal 0, @product.related_product_associations.count
  end

  test "typing filters the list from the server" do
    visit_picker

    fill_in_search "Pulseira"

    assert_selector "[data-product-id='#{@far_away.id}']", wait: 5
    assert_no_selector "[data-product-id='#{@sibling.id}']"
  end

  test "pressing Enter in the search box does not save the product" do
    visit_picker

    find("[data-related-products-target='search']").send_keys("Pulseira", :enter)
    wait_for_search_results

    assert_current_path related_products_bo_product_path(org_slug: @organisation.slug, id: @product.id)
    assert_no_selector ".alert", text: I18n.t("bo.products.related.updated")
    assert_equal 0, @product.related_product_associations.count
  end

  test "adding a product moves it out of the list and into the selection" do
    visit_picker

    find("button[data-product-id='#{@sibling.id}'][data-action*='add']").click

    within "#selected-products-list" do
      assert_text @sibling.name
    end
    assert_no_selector "[data-related-products-target='availableItem'][data-product-id='#{@sibling.id}']:not(.d-none)"
  end

  # Results come back from the server knowing nothing about a selection that has
  # not been saved yet, so an added product must not reappear after a search.
  test "a product added stays hidden after searching again" do
    visit_picker

    find("button[data-product-id='#{@sibling.id}'][data-action*='add']").click
    fill_in_search "Anel"

    assert_selector "[data-product-id='#{@sibling.id}'].d-none", visible: :all, wait: 5
  end

  test "saving keeps what was picked" do
    visit_picker

    find("button[data-product-id='#{@sibling.id}'][data-action*='add']").click
    click_on I18n.t("bo.common.actions.save")

    assert_selector ".alert", text: I18n.t("bo.products.related.updated"), wait: 5
    assert_equal [ @sibling.id ], @product.related_product_associations.order(:position).pluck(:related_product_id)
  end

  def fill_in_search(text)
    find("[data-related-products-target='search']").fill_in with: text
  end

  # Somewhere to stand: the search is debounced and answered over the network,
  # so nothing about the page is settled until the results reflect the query.
  def wait_for_search_results
    assert_selector "[data-product-id='#{@far_away.id}']", wait: 5
  end
end
