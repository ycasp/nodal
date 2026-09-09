require "test_helper"

class HostAwareUrlHelpersTest < ActiveSupport::TestCase
  # Minimal stub that mimics how ApplicationController/ApplicationHelper mix
  # URL helpers in: Rails helpers first, our overrides on top.
  class Harness
    include Rails.application.routes.url_helpers
    include HostAwareUrlHelpers

    attr_accessor :request
  end

  setup do
    @org = Organisation.create!(name: "Host Org", custom_domain: "b2b.example.test")
    @harness = Harness.new
  end

  test "dispatcher installs overrides for routes with custom_host_ counterparts" do
    overrides = HostAwareUrlHelpers.instance_methods(false).map(&:to_s)
    assert_includes overrides, "products_path"
    assert_includes overrides, "products_url"
    assert_includes overrides, "checkout_path"
    assert_includes overrides, "cart_path"
  end

  test "on_custom_host? is true when request host matches an org custom_domain" do
    @harness.request = stub_request("b2b.example.test")
    assert @harness.on_custom_host?
  end

  test "on_custom_host? is false on the canonical host" do
    @harness.request = stub_request("nodal-seiri.dev")
    assert_not @harness.on_custom_host?
  end

  test "on_custom_host? is false when no request is present" do
    @harness.request = nil
    assert_not @harness.on_custom_host?
  end

  test "products_path on canonical host emits slug-based URL" do
    @harness.request = stub_request("nodal-seiri.dev")
    assert_equal "/perestrelo-cunha/products", @harness.products_path(org_slug: "perestrelo-cunha")
  end

  test "products_path on custom host emits slug-less URL" do
    @harness.request = stub_request("b2b.example.test")
    assert_equal "/products", @harness.products_path
  end

  test "checkout_path on custom host emits slug-less URL" do
    @harness.request = stub_request("b2b.example.test")
    assert_equal "/checkout", @harness.checkout_path
  end

  test "cart_path on canonical host emits slug-based URL" do
    @harness.request = stub_request("nodal-seiri.dev")
    assert_equal "/perestrelo-cunha/cart", @harness.cart_path(org_slug: "perestrelo-cunha")
  end

  test "redundant org_slug kwarg is dropped on custom host (no leakage as query string)" do
    @harness.request = stub_request("b2b.example.test")
    assert_equal "/products", @harness.products_path(org_slug: "perestrelo-cunha")
  end

  private

  def stub_request(host)
    Struct.new(:host).new(host)
  end
end
