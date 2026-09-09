require "test_helper"

class Bo::RelatedProductsPickerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organisation = Organisation.create!(name: "Related Picker Org", currency: "EUR")
    @admin = Member.create!(email: "related-admin@example.com", password: "password123",
                            first_name: "Ana", last_name: "Admin")
    @organisation.org_members.create!(member: @admin, role: "owner", active: true)
    sign_in @admin

    @rings = @organisation.categories.create!(name: "Anéis")
    @product = product("Anel Marcassites Prata", category: @rings)
  end

  def product(name, category: nil, published: true, sku: nil)
    p = @organisation.products.create!(name: name, unit_price: 1000, published: published, sku: sku)
    p.categories << category if category
    p
  end

  def search(**params)
    get related_products_search_bo_product_path(org_slug: @organisation.slug, id: @product.id, **params)
  end

  # The whole point of the rewrite: the page itself must not carry the catalog.
  # It used to render every published product inline — 2766 of them in
  # production — and time out.
  test "the page does not list the catalog" do
    20.times { |i| product("Outro Produto #{i}", category: @rings) }

    get related_products_bo_product_path(org_slug: @organisation.slug, id: @product.id)

    assert_response :success
    assert_select "[data-related-products-target='availableItem']", 0
    assert_select "turbo-frame#related_products_results"
  end

  test "with no query it offers products from the same category" do
    same_category = product("Anel Prata Azul", category: @rings)
    other_category = product("Colar Prata", category: @organisation.categories.create!(name: "Colares"))

    search

    assert_response :success
    assert_match same_category.name, response.body
    assert_no_match(/#{other_category.name}/, response.body)
  end

  # Caught on screen, not by the first round of tests: a product with no
  # category matched nothing, so the picker said "nothing to add" while the
  # catalog was full. Offering the catalog is better than offering nothing.
  test "falls back to the catalog when the product has no category" do
    uncategorised = product("Aliança Prata")
    other = product("Colar Prata")

    get related_products_search_bo_product_path(org_slug: @organisation.slug, id: uncategorised.id)

    assert_response :success
    assert_match other.name, response.body
    assert_select "[data-related-products-target='availableItem']", minimum: 1
  end

  test "falls back to the catalog when it is the only product in its category" do
    lonely = product("Anel Único", category: @organisation.categories.create!(name: "Únicos"))
    other = product("Colar Prata")

    get related_products_search_bo_product_path(org_slug: @organisation.slug, id: lonely.id)

    assert_response :success
    assert_match other.name, response.body
  end

  test "search finds a product by name" do
    match = product("Pulseira Dourada", category: @organisation.categories.create!(name: "Pulseiras"))

    search(query: "Pulseira")

    assert_response :success
    assert_match match.name, response.body
  end

  test "search finds a product by SKU" do
    match = product("Brinco Simples", sku: "BR9988")

    search(query: "BR9988")

    assert_response :success
    assert_match match.name, response.body
  end

  # The search runs unaccent on both sides, so how the user types the accent
  # must not decide whether they find anything.
  test "search ignores accents" do
    match = product("Colar Coração")

    search(query: "coracao")

    assert_response :success
    assert_match match.name, response.body
  end

  test "never offers the product itself" do
    search(query: @product.name)

    assert_response :success
    assert_no_match(/data-product-id="#{@product.id}"/, response.body)
  end

  test "does not offer unpublished products" do
    hidden = product("Anel Escondido", category: @rings, published: false)

    search(query: "Escondido")

    assert_response :success
    assert_no_match(/#{hidden.name}/, response.body)
  end

  test "says so when a search matches nothing" do
    search(query: "zzzznaoexiste")

    assert_response :success
    assert_select "[data-related-products-target='availableItem']", 0
  end

  # A page of results, not the whole catalog, however many match.
  test "pages long result sets" do
    40.times { |i| product("Anel Serie #{i}", category: @rings) }

    search

    assert_response :success
    assert_equal 30, css_select("[data-related-products-target='availableItem']").size
  end

  # Relationships are mutual: picking B on A's page has to give B a link back to
  # A, and dropping it from either side has to drop both. Without the second row
  # RelatedProductsFetcher, which only reads `product_id = self`, never shows the
  # link from B.
  def save_related(product, ids)
    patch update_related_products_bo_product_path(org_slug: @organisation.slug, id: product.id),
          params: { related_product_ids: ids.map(&:to_s), hide_related_products: "0" }
  end

  test "picking a product links it back the other way" do
    other = product("Colar Prata")

    save_related(@product, [ other.id ])

    assert RelatedProduct.exists?(product: @product, related_product: other)
    assert RelatedProduct.exists?(product: other, related_product: @product),
      "the other product must link back"
  end

  test "dropping a product removes both directions" do
    other = product("Colar Prata")
    save_related(@product, [ other.id ])

    save_related(@product, [])

    assert_not RelatedProduct.exists?(product: @product, related_product: other)
    assert_not RelatedProduct.exists?(product: other, related_product: @product)
  end

  test "dropping it from the other side removes both directions too" do
    other = product("Colar Prata")
    save_related(@product, [ other.id ])

    save_related(other, [])

    assert_not RelatedProduct.exists?(product: other, related_product: @product)
    assert_not RelatedProduct.exists?(product: @product, related_product: other),
      "removing from one side must not leave the other half behind"
  end

  test "saving one product does not disturb another product's links" do
    other = product("Colar Prata")
    third = product("Brinco Prata")
    save_related(@product, [ other.id ])
    save_related(third, [ other.id ])

    save_related(@product, [])

    assert RelatedProduct.exists?(product: third, related_product: other)
    assert RelatedProduct.exists?(product: other, related_product: third),
      "only the pair being edited should change"
  end

  test "saving the same selection twice is harmless" do
    other = product("Colar Prata")

    save_related(@product, [ other.id ])
    save_related(@product, [ other.id ])

    assert_equal 1, RelatedProduct.where(product: @product, related_product: other).count
    assert_equal 1, RelatedProduct.where(product: other, related_product: @product).count
  end
end
