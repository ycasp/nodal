require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Nav Org")
  end

  test "categories are published by default" do
    category = Category.create!(organisation: @org, name: "Aneis")
    assert category.published?
  end

  test "visible scope excludes unpublished and discarded categories" do
    shown = Category.create!(organisation: @org, name: "Visivel")
    hidden = Category.create!(organisation: @org, name: "Oculta", published: false)
    trashed = Category.create!(organisation: @org, name: "Apagada")
    trashed.discard

    visible = @org.categories.visible
    assert_includes visible, shown
    assert_not_includes visible, hidden
    assert_not_includes visible, trashed
  end

  test "hiding a category does not detach its products" do
    category = Category.create!(organisation: @org, name: "Em construcao")
    product = Product.create!(organisation: @org, name: "Fio", unit_price: 1000, published: true)
    category.products << product

    category.update!(published: false)

    assert_equal [product], category.reload.products.to_a,
                 "hiding is navigation-only; discarding is what detaches products"
  end

  test "nav_style is nil when the org left the defaults alone" do
    assert_nil Category.new.nav_style
  end

  test "nav_style composes colour and emphasis" do
    category = Category.new(color: "#d63384", nav_bold: true, nav_italic: true)
    assert_equal "color: #d63384; font-weight: 600; font-style: italic", category.nav_style

    assert_equal "font-weight: 600", Category.new(nav_bold: true).nav_style
    assert_equal "color: #198754", Category.new(color: "#198754").nav_style
  end

  test "name keeps the casing the org typed" do
    assert_equal "PRATA", Category.create!(organisation: @org, name: "PRATA").name
    assert_equal "Fecho PVD", Category.create!(organisation: @org, name: "  Fecho PVD  ").name,
                 "surrounding whitespace is still trimmed"
    assert_equal "brincos", Category.create!(organisation: @org, name: "brincos").name
  end

  test "names still collide case-insensitively" do
    Category.create!(organisation: @org, name: "PRATA")
    duplicate = Category.new(organisation: @org, name: "Prata")

    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test "colour must be a hex value" do
    category = Category.new(organisation: @org, name: "Cor Ma", color: "red; background: url(x)")
    assert_not category.valid?
    assert category.errors[:color].any?

    assert Category.new(organisation: @org, name: "Cor Boa", color: "#abc").valid?
    assert Category.new(organisation: @org, name: "Sem Cor", color: "").valid?
  end
end
