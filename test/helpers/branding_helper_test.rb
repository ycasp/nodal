require "test_helper"

class BrandingHelperTest < ActionView::TestCase
  # sale_badge_label falls back to the translated default when the org sets no
  # custom text, and uses the custom text when present.
  test "sale_badge_label falls back to the translated default" do
    org = Organisation.new(sale_badge_text: nil)
    assert_equal I18n.t("storefront.products.index.sale_badge"), sale_badge_label(org)
  end

  test "sale_badge_label uses the org custom text when set" do
    org = Organisation.new(sale_badge_text: "SALDOS")
    assert_equal "SALDOS", sale_badge_label(org)
  end

  test "sale_badge_label handles a nil organisation" do
    assert_equal I18n.t("storefront.products.index.sale_badge"), sale_badge_label(nil)
  end

  # sale_badge_style uses the effective colour and picks a contrasting text
  # colour so the badge stays readable.
  test "sale_badge_style defaults to red with white text" do
    style = sale_badge_style(Organisation.new(sale_badge_color: nil))
    assert_includes style, "background-color: #dc3545"
    assert_includes style, "color: #ffffff"
  end

  test "sale_badge_style uses a custom colour with contrast-aware text" do
    dark = sale_badge_style(Organisation.new(sale_badge_color: "#003366"))
    assert_includes dark, "background-color: #003366"
    assert_includes dark, "color: #ffffff"

    light = sale_badge_style(Organisation.new(sale_badge_color: "#ffee00"))
    assert_includes light, "background-color: #ffee00"
    assert_includes light, "color: #000000"
  end
end
