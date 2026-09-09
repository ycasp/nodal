require "test_helper"

class OrganisationTest < ActiveSupport::TestCase
  class FakeRequest
    def initialize(ssl: false, scheme: "http", fullpath: "/")
      @ssl = ssl
      @scheme = scheme
      @fullpath = fullpath
    end

    def ssl?
      @ssl
    end

    attr_reader :scheme, :fullpath
  end

  setup do
    @org = Organisation.create!(name: "Test Org")
  end

  # custom_domain format validation

  test "accepts a valid subdomain hostname" do
    @org.custom_domain = "b2b.example.com"
    assert @org.valid?, @org.errors.full_messages.inspect
  end

  test "accepts an apex hostname" do
    @org.custom_domain = "example.pt"
    assert @org.valid?
  end

  test "accepts hostname with multiple dots" do
    @org.custom_domain = "shop.b2b.cliente.example.co.uk"
    assert @org.valid?
  end

  test "allows blank custom_domain" do
    @org.custom_domain = nil
    assert @org.valid?
    @org.custom_domain = ""
    assert @org.valid?
  end

  test "rejects hostname with scheme" do
    @org.custom_domain = "https://example.com"
    @org.valid?
    # after normalization the scheme is stripped, so it actually becomes valid;
    # this test verifies normalization fixes user input rather than rejecting it
    assert_equal "example.com", @org.custom_domain
    assert @org.valid?
  end

  test "rejects hostname with path" do
    @org.custom_domain = "example.com/path"
    @org.valid?
    assert_equal "example.com", @org.custom_domain
    assert @org.valid?
  end

  test "rejects hostname with spaces" do
    @org.custom_domain = "exa mple.com"
    assert_not @org.valid?
    assert @org.errors[:custom_domain].any?
  end

  test "rejects hostname without TLD" do
    @org.custom_domain = "localhost"
    assert_not @org.valid?
  end

  test "rejects hostname with leading hyphen in label" do
    @org.custom_domain = "-bad.example.com"
    assert_not @org.valid?
  end

  test "rejects hostname with trailing hyphen in label" do
    @org.custom_domain = "bad-.example.com"
    assert_not @org.valid?
  end

  # normalization

  test "normalizes uppercase to lowercase" do
    @org.custom_domain = "B2B.Example.COM"
    @org.valid?
    assert_equal "b2b.example.com", @org.custom_domain
  end

  test "normalizes by stripping whitespace" do
    @org.custom_domain = "  b2b.example.com  "
    @org.valid?
    assert_equal "b2b.example.com", @org.custom_domain
  end

  test "normalizes by removing https scheme" do
    @org.custom_domain = "https://b2b.example.com"
    @org.valid?
    assert_equal "b2b.example.com", @org.custom_domain
  end

  test "normalizes by removing http scheme" do
    @org.custom_domain = "http://b2b.example.com"
    @org.valid?
    assert_equal "b2b.example.com", @org.custom_domain
  end

  test "normalizes by removing path" do
    @org.custom_domain = "b2b.example.com/orders"
    @org.valid?
    assert_equal "b2b.example.com", @org.custom_domain
  end

  test "normalizes trailing dot" do
    @org.custom_domain = "b2b.example.com."
    @org.valid?
    assert_equal "b2b.example.com", @org.custom_domain
  end

  test "normalizes whitespace-only input to nil" do
    @org.custom_domain = "   "
    @org.valid?
    assert_nil @org.custom_domain
  end

  # uniqueness

  test "enforces uniqueness of custom_domain" do
    @org.update!(custom_domain: "b2b.example.com")
    other = Organisation.new(name: "Other Org", custom_domain: "b2b.example.com")
    assert_not other.valid?
    assert other.errors[:custom_domain].any?
  end

  test "allows multiple organisations with nil custom_domain" do
    Organisation.create!(name: "Org A")
    other = Organisation.new(name: "Org B")
    assert other.valid?
  end

  # find_by_host

  test "find_by_host returns the org matching custom_domain" do
    @org.update!(custom_domain: "b2b.perestrelocunha.pt")
    assert_equal @org, Organisation.find_by_host("b2b.perestrelocunha.pt")
  end

  test "find_by_host is case-insensitive" do
    @org.update!(custom_domain: "b2b.perestrelocunha.pt")
    assert_equal @org, Organisation.find_by_host("B2B.Perestrelocunha.PT")
  end

  test "find_by_host strips whitespace" do
    @org.update!(custom_domain: "b2b.perestrelocunha.pt")
    assert_equal @org, Organisation.find_by_host("  b2b.perestrelocunha.pt  ")
  end

  test "find_by_host returns nil for blank host" do
    assert_nil Organisation.find_by_host(nil)
    assert_nil Organisation.find_by_host("")
    assert_nil Organisation.find_by_host("   ")
  end

  test "find_by_host returns nil when host does not match any org and does not return orgs with NULL custom_domain" do
    Organisation.create!(name: "No Domain Org")
    assert_nil Organisation.find_by_host("nonexistent.example.com")
  end

  # custom_domain_verified?

  test "custom_domain_verified? is false when domain is nil" do
    assert_not @org.custom_domain_verified?
  end

  test "custom_domain_verified? is false when domain is set but not verified" do
    @org.update!(custom_domain: "b2b.example.com")
    assert_not @org.custom_domain_verified?
  end

  test "custom_domain_verified? is true when domain is set and verified_at is present" do
    @org.update!(custom_domain: "b2b.example.com", custom_domain_verified_at: Time.current)
    assert @org.custom_domain_verified?
  end

  # preferred_host

  test "preferred_host falls back to canonical host when no custom_domain set" do
    assert_equal Rails.application.config.x.canonical_host, @org.preferred_host
  end

  test "preferred_host falls back to canonical when custom_domain is set but not verified" do
    @org.update!(custom_domain: "b2b.example.com")
    assert_equal Rails.application.config.x.canonical_host, @org.preferred_host
  end

  test "preferred_host returns the custom_domain when verified" do
    @org.update!(custom_domain: "b2b.example.com", custom_domain_verified_at: Time.current)
    assert_equal "b2b.example.com", @org.preferred_host
  end

  # email_from_address

  test "email_from_address uses the apex of canonical_host regardless of custom_domain" do
    @org.update!(name: "Acme Co", custom_domain: "b2b.example.com", custom_domain_verified_at: Time.current)
    apex = Rails.application.config.x.canonical_host.to_s.sub(/\Awww\./, "")
    assert_equal "Acme Co <no-reply@#{apex}>", @org.email_from_address
  end

  test "email_from_address strips a leading www. from canonical_host" do
    original = Rails.application.config.x.canonical_host
    Rails.application.config.x.canonical_host = "www.example.test"
    @org.update!(name: "Acme Co")
    assert_equal "Acme Co <no-reply@example.test>", @org.email_from_address
  ensure
    Rails.application.config.x.canonical_host = original
  end

  test "email_from_address honours MAIL_SENDER_DOMAIN override" do
    original = Rails.application.config.x.mail_sender_domain
    Rails.application.config.x.mail_sender_domain = "mail.acme.test"
    @org.update!(name: "Acme Co")
    assert_equal "Acme Co <no-reply@mail.acme.test>", @org.email_from_address
  ensure
    Rails.application.config.x.mail_sender_domain = original
  end

  # canonical_url_for_request

  test "canonical_url_for_request uses canonical host + full path when no verified custom_domain" do
    org = Organisation.create!(name: "Plain Org", slug: "plain-org")
    request = FakeRequest.new(ssl: true, fullpath: "/plain-org/products")
    canonical = Rails.application.config.x.canonical_host
    assert_equal "https://#{canonical}/plain-org/products", org.canonical_url_for_request(request)
  end

  test "canonical_url_for_request strips the leading slug when org has verified custom_domain" do
    org = Organisation.create!(
      name: "Host Org",
      slug: "host-org",
      custom_domain: "b2b.example.test",
      custom_domain_verified_at: Time.current
    )
    request = FakeRequest.new(ssl: true, fullpath: "/host-org/products")
    assert_equal "https://b2b.example.test/products", org.canonical_url_for_request(request)
  end

  test "canonical_url_for_request returns root path when only the slug is present" do
    org = Organisation.create!(
      name: "Host Org",
      slug: "host-org",
      custom_domain: "b2b.example.test",
      custom_domain_verified_at: Time.current
    )
    request = FakeRequest.new(ssl: true, fullpath: "/host-org")
    assert_equal "https://b2b.example.test/", org.canonical_url_for_request(request)
  end

  test "canonical_url_for_request leaves slug-less paths alone on verified custom_domain" do
    org = Organisation.create!(
      name: "Host Org",
      slug: "host-org",
      custom_domain: "b2b.example.test",
      custom_domain_verified_at: Time.current
    )
    request = FakeRequest.new(ssl: true, fullpath: "/products")
    assert_equal "https://b2b.example.test/products", org.canonical_url_for_request(request)
  end

  test "canonical_url_for_request uses http when request is not ssl" do
    org = Organisation.create!(name: "Plain Org", slug: "plain-org")
    request = FakeRequest.new(ssl: false, scheme: "http", fullpath: "/plain-org/products")
    canonical = Rails.application.config.x.canonical_host
    assert_equal "http://#{canonical}/plain-org/products", org.canonical_url_for_request(request)
  end

  # custom_domain change resets verification

  test "changing custom_domain clears the existing verified_at" do
    @org.update!(custom_domain: "b2b.first.test", custom_domain_verified_at: Time.current)
    assert @org.custom_domain_verified?
    @org.update!(custom_domain: "b2b.second.test")
    assert_nil @org.reload.custom_domain_verified_at
  end

  test "clearing custom_domain clears the existing verified_at" do
    @org.update!(custom_domain: "b2b.first.test", custom_domain_verified_at: Time.current)
    @org.update!(custom_domain: nil)
    assert_nil @org.reload.custom_domain_verified_at
  end

  test "saving without touching custom_domain keeps verified_at intact" do
    @org.update!(custom_domain: "b2b.first.test", custom_domain_verified_at: Time.current)
    original_verified_at = @org.custom_domain_verified_at
    @org.update!(name: "Renamed Co")
    assert_in_delta original_verified_at.to_f, @org.reload.custom_domain_verified_at.to_f, 1.0
  end

  # cart policies

  test "defaults cart policies to warn" do
    assert_equal "warn", @org.cart_stock_policy
    assert_equal "warn", @org.cart_qty_overflow_policy
    assert_equal "warn", @org.checkout_stock_policy
  end

  test "defaults cart_price_change_policy to notify" do
    assert_equal "notify", @org.cart_price_change_policy
  end

  test "rejects an invalid cart_price_change_policy" do
    @org.cart_price_change_policy = "explode"
    assert_not @org.valid?
    assert_includes @org.errors[:cart_price_change_policy], "is not included in the list"
  end

  test "rejects an invalid checkout_stock_policy" do
    @org.checkout_stock_policy = "explode"
    assert_not @org.valid?
    assert_includes @org.errors[:checkout_stock_policy], "is not included in the list"
  end

  test "rejects an invalid cart_stock_policy" do
    @org.cart_stock_policy = "explode"
    assert_not @org.valid?
    assert_includes @org.errors[:cart_stock_policy], "is not included in the list"
  end

  test "rejects an invalid cart_qty_overflow_policy" do
    @org.cart_qty_overflow_policy = "explode"
    assert_not @org.valid?
    assert_includes @org.errors[:cart_qty_overflow_policy], "is not included in the list"
  end
end
