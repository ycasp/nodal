require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  # A throwaway subclass used to exercise ApplicationMailer's private host
  # plumbing without coupling these tests to any production mailer's
  # template/dependency stack.
  class TestProbeMailer < ApplicationMailer
    def probe(organisation)
      @organisation = organisation
      self
    end

    public :on_custom_host?, :default_url_options
  end

  setup do
    @canonical = Rails.application.config.x.canonical_host
  end

  test "default from uses canonical host" do
    expected = "no-reply@#{@canonical}"
    from = ApplicationMailer.default[:from]
    actual = from.respond_to?(:call) ? from.call : from
    assert_equal expected, actual
  end

  test "on_custom_host? is false when @organisation is nil" do
    mailer = TestProbeMailer.new.probe(nil)
    assert_not mailer.on_custom_host?
  end

  test "on_custom_host? is false when @organisation has no custom_domain" do
    org = Organisation.create!(name: "Plain Org")
    mailer = TestProbeMailer.new.probe(org)
    assert_not mailer.on_custom_host?
  end

  test "on_custom_host? is false when custom_domain is set but not verified" do
    org = Organisation.create!(name: "Pending Org", custom_domain: "b2b.pending.test")
    mailer = TestProbeMailer.new.probe(org)
    assert_not mailer.on_custom_host?
  end

  test "on_custom_host? is true when custom_domain is verified" do
    org = Organisation.create!(
      name: "Verified Org",
      custom_domain: "b2b.verified.test",
      custom_domain_verified_at: Time.current
    )
    mailer = TestProbeMailer.new.probe(org)
    assert mailer.on_custom_host?
  end

  test "default_url_options exposes canonical host when org has no verified custom_domain" do
    org = Organisation.create!(name: "Plain Org")
    mailer = TestProbeMailer.new.probe(org)
    assert_equal @canonical, mailer.default_url_options[:host]
    assert_equal "https", mailer.default_url_options[:protocol]
  end

  test "default_url_options exposes custom_domain when verified" do
    org = Organisation.create!(
      name: "Verified Org",
      custom_domain: "b2b.verified.test",
      custom_domain_verified_at: Time.current
    )
    mailer = TestProbeMailer.new.probe(org)
    assert_equal "b2b.verified.test", mailer.default_url_options[:host]
  end

  test "default_url_options leaves host untouched when @organisation is nil" do
    mailer = TestProbeMailer.new.probe(nil)
    # super here returns whatever ActionMailer's class-level
    # default_url_options has — typically host: ENV['APP_HOST'] in prod or
    # localhost in dev/test. Either way our override should NOT have added
    # an org-derived host key.
    refute mailer.default_url_options.key?(:protocol) && mailer.default_url_options[:protocol] == "https" && @canonical == mailer.default_url_options[:host],
           "Expected no org-derived host when @organisation is nil"
  end

  test "URL helpers respect @organisation's preferred host on verified custom domain" do
    org = Organisation.create!(
      name: "Verified Org",
      slug: "verified-org",
      custom_domain: "b2b.verified.test",
      custom_domain_verified_at: Time.current
    )
    mailer = TestProbeMailer.new.probe(org)
    # products_url should pick the custom_host_ variant (slug-less) AND set
    # the host to the org's preferred_host (via default_url_options).
    assert_equal "https://b2b.verified.test/products", mailer.products_url
  end

  test "URL helpers stay slug-based when org has no verified custom domain" do
    org = Organisation.create!(name: "Plain Org", slug: "plain-org")
    mailer = TestProbeMailer.new.probe(org)
    assert_equal "https://#{@canonical}/plain-org/products",
                 mailer.products_url(org_slug: "plain-org")
  end
end
