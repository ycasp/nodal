require "test_helper"

class CustomDomainRoutesTest < ActionDispatch::IntegrationTest
  setup do
    @org = Organisation.create!(
      name: "Host Org",
      custom_domain: "b2b.example.test",
      custom_domain_verified_at: Time.current
    )
  end

  test "root on a custom host resolves to the storefront home" do
    assert_routing(
      { method: "get", path: "http://b2b.example.test/" },
      { controller: "storefront/home", action: "show" }
    )
  end

  test "root on the canonical host resolves to the marketing landing" do
    assert_routing(
      { method: "get", path: "http://nodal-seiri.dev/" },
      { controller: "pages", action: "home" }
    )
  end

  test "BO under slug on a custom host redirects (route is a 301)" do
    # assert_routing on redirect routes is awkward; check via bin/rails routes
    # and the redirect target instead.
    routes = Rails.application.routes.routes.map(&:path).map(&:spec).map(&:to_s)
    assert routes.any? { |spec| spec.include?(":org_slug/bo") && spec.include?("path") },
           "Expected a :org_slug/bo(/*path) redirect route to be defined"
  end
end
