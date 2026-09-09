require "test_helper"

# Storefront product listing — attribute filter facets.
#
# The key behaviour under test: filters are INDEPENDENT facets. Selecting one
# value of an attribute must NOT hide the other values of that same attribute
# (OR within an attribute stays usable), while still narrowing the OTHER
# attributes and the product list (AND across attributes).
class ProductsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = Organisation.create!(name: "Facet Org")

    attr_defaults = { display_type: "dropdown", card_display_mode: "values" }
    @cor = @org.product_attributes.create!(name: "Cor", slug: "cor", **attr_defaults)
    @vermelho = @cor.product_attribute_values.create!(value: "vermelho", slug: "vermelho")
    @azul     = @cor.product_attribute_values.create!(value: "azul", slug: "azul")
    @verde    = @cor.product_attribute_values.create!(value: "verde", slug: "verde")

    @espessura = @org.product_attributes.create!(name: "Espessura", slug: "espessura", **attr_defaults)
    @e10 = @espessura.product_attribute_values.create!(value: "10", slug: "10")
    @e20 = @espessura.product_attribute_values.create!(value: "20", slug: "20")

    @category = Category.create!(organisation: @org, name: "Tintas", slug: "tintas-#{SecureRandom.hex(4)}")

    # A: vermelho + 10   B: azul + 10   C: verde + 20
    @a = build_product("Produto A", [@vermelho, @e10])
    @b = build_product("Produto B", [@azul, @e10])
    @c = build_product("Produto C", [@verde, @e20])

    @customer = Customer.create!(organisation: @org, company_name: "Cliente", contact_name: "Zé", active: true)
    @user = @customer.customer_users.create!(
      organisation: @org, email: "zé@example.com", password: "password123",
      active: true, invitation_accepted_at: Time.current
    )
    sign_in @user
  end

  test "selecting one attribute value keeps its sibling values selectable (OR within attribute)" do
    get products_path(org_slug: @org.slug, category: @category.slug, attrs: { "cor" => ["vermelho"] })
    assert_response :success

    labels = filter_value_labels
    # The selected value AND its siblings must all still be offered.
    assert_includes labels, "vermelho", "selected value should remain visible"
    assert_includes labels, "azul", "sibling value must stay selectable so OR is usable"
    assert_includes labels, "verde", "sibling value must stay selectable so OR is usable"

    # The applied value comes pre-checked; its siblings do not (apply-on-close state).
    assert_select ".attribute-filters input.attr-filter-check[value=vermelho][checked]"
    assert_select ".attribute-filters input.attr-filter-check[value=azul]:not([checked])"
  end

  test "selecting one attribute narrows a different attribute (AND across attributes)" do
    get products_path(org_slug: @org.slug, category: @category.slug, attrs: { "cor" => ["vermelho"] })
    assert_response :success

    # Only Produto A (vermelho) matches, so Espessura should offer 10 but not 20.
    labels = filter_value_labels
    assert_includes labels, "10", "espessura present on the matching product must stay offered"
    assert_not_includes labels, "20", "espessura only on non-matching products must be filtered out"
  end

  test "sidebar category count only counts products the customer can see" do
    # An extra product linked to the category but NOT published must not inflate
    # the sidebar count (it never appears in the grid).
    hidden = Product.create!(organisation: @org, name: "Escondido", unit_price: 1000,
                             published: false, available: true, has_variants: true)
    CategoryProduct.create!(category: @category, product: hidden)

    get products_path(org_slug: @org.slug)
    assert_response :success

    # @a, @b, @c are published (3); the hidden one is excluded → count is 3, not 4.
    assert_select "li[data-category-id=?] .category-count", @category.id.to_s, text: "3"
  end

  test "with no filters all values of every attribute are offered" do
    get products_path(org_slug: @org.slug, category: @category.slug)
    assert_response :success

    labels = filter_value_labels
    %w[vermelho azul verde 10 20].each do |v|
      assert_includes labels, v
    end
  end

  private

  # Variable product carrying one published, attribute-bearing variant.
  def build_product(name, attribute_values)
    product = Product.create!(organisation: @org, name: name, unit_price: 1000,
                              published: true, available: true, has_variants: true)
    CategoryProduct.create!(category: @category, product: product)
    variant = product.product_variants.create!(name: "#{name} V", published: true, is_default: false)
    attribute_values.each do |val|
      VariantAttributeValue.create!(product_variant: variant, product_attribute_value: val)
    end
    product
  end

  # The value slugs actually offered inside the (desktop) attribute filter dropdowns.
  def filter_value_labels
    css_select(".attribute-filters input.attr-filter-check").map { |n| n["value"] }
  end
end
