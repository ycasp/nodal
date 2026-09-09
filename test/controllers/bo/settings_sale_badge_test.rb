require "test_helper"

# The sale-badge text/colour are edited on the general storefront settings form
# (bo/settings). This guards that the two new fields are permitted and persist,
# and that an invalid colour is rejected by the model validation.
class Bo::SettingsSaleBadgeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organisation = Organisation.create!(name: "Badge Org", currency: "EUR")
    @member = Member.create!(
      email: "badge-admin@example.com",
      password: "password123",
      first_name: "Badge",
      last_name: "Admin"
    )
    @organisation.org_members.create!(member: @member, role: "owner", active: true)
    sign_in @member
  end

  test "updating settings persists custom sale badge text and colour" do
    patch bo_settings_path(org_slug: @organisation.slug), params: {
      organisation: { sale_badge_text: "SALDOS", sale_badge_color: "#00aa55" }
    }

    @organisation.reload
    assert_equal "SALDOS", @organisation.sale_badge_text
    assert_equal "#00aa55", @organisation.sale_badge_color
  end

  test "blank sale badge fields fall back to defaults" do
    @organisation.update!(sale_badge_text: "OLD", sale_badge_color: "#123456")

    patch bo_settings_path(org_slug: @organisation.slug), params: {
      organisation: { sale_badge_text: "", sale_badge_color: "" }
    }

    @organisation.reload
    assert @organisation.sale_badge_text.blank?
    assert @organisation.sale_badge_color.blank?
    assert_equal "#dc3545", @organisation.effective_sale_badge_color
  end

  test "the badge defaults to shown and can be turned off" do
    assert @organisation.show_sale_badge, "badge should default to shown"

    patch bo_settings_path(org_slug: @organisation.slug), params: {
      organisation: { show_sale_badge: "0" }
    }
    assert_not @organisation.reload.show_sale_badge

    patch bo_settings_path(org_slug: @organisation.slug), params: {
      organisation: { show_sale_badge: "1" }
    }
    assert @organisation.reload.show_sale_badge
  end

  test "an invalid hex colour is rejected" do
    patch bo_settings_path(org_slug: @organisation.slug), params: {
      organisation: { sale_badge_color: "notacolour" }
    }

    @organisation.reload
    assert_nil @organisation.sale_badge_color
  end
end
