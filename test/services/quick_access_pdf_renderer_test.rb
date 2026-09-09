require "test_helper"

class QuickAccessPdfRendererTest < ActiveSupport::TestCase
  setup do
    @org = Organisation.create!(name: "Plain Org")
    @customer = @org.customers.create!(
      company_name: "Customer Co",
      contact_name: "Test Contact",
      active: true
    )
    @customer_user = @customer.customer_users.create!(
      email: "user@example.test",
      organisation: @org,
      password: SecureRandom.urlsafe_base64(16)
    )
    @token = @customer_user.quick_access_tokens.create!
    @renderer = QuickAccessPdfRenderer.new(token: @token, layout: :card)
  end

  test "on_custom_host? is false when the token's org has no verified custom_domain" do
    assert_not @renderer.on_custom_host?
  end

  test "on_custom_host? is true when the token's org has a verified custom_domain" do
    @org.update!(custom_domain: "b2b.example.test", custom_domain_verified_at: Time.current)
    reset_renderer_org_memo
    assert @renderer.on_custom_host?
  end

  test "default_url_options uses localhost in non-production environments" do
    opts = @renderer.default_url_options
    assert_equal "localhost", opts[:host]
    assert_equal 3000, opts[:port]
    assert_equal "http", opts[:protocol]
  end

  test "URL generation embeds the org slug when no verified custom_domain" do
    url = @renderer.quick_access_url(org_slug: @org.slug, token: @token.token)
    assert_includes url, "/#{@org.slug}/quick/#{@token.token}"
  end

  test "URL generation drops the org slug when the org has a verified custom_domain" do
    @org.update!(custom_domain: "b2b.example.test", custom_domain_verified_at: Time.current)
    reset_renderer_org_memo
    url = @renderer.quick_access_url(org_slug: @org.slug, token: @token.token)
    assert_includes url, "/quick/#{@token.token}"
    assert_not_includes url, "/#{@org.slug}/"
  end

  private

  def reset_renderer_org_memo
    @renderer.instance_variable_set(:@organisation, nil)
  end
end
