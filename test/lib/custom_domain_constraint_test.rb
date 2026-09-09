require "test_helper"
require "minitest/mock"

class CustomDomainConstraintTest < ActiveSupport::TestCase
  setup do
    @constraint = CustomDomainConstraint.new
  end

  test "matches when an org has the request host as custom_domain" do
    Organisation.create!(name: "Host Org", custom_domain: "b2b.example.test")
    request = stub_request("b2b.example.test")
    assert @constraint.matches?(request)
  end

  test "is case-insensitive" do
    Organisation.create!(name: "Host Org", custom_domain: "b2b.example.test")
    request = stub_request("B2B.Example.Test")
    assert @constraint.matches?(request)
  end

  test "does not match the canonical host" do
    Organisation.create!(name: "Slug Org")
    request = stub_request("nodal-seiri.dev")
    assert_not @constraint.matches?(request)
  end

  test "does not match an unknown host" do
    Organisation.create!(name: "Host Org", custom_domain: "b2b.example.test")
    request = stub_request("other.example.com")
    assert_not @constraint.matches?(request)
  end

  test "does not match when host is blank" do
    request = stub_request("")
    assert_not @constraint.matches?(request)
  end

  test "returns false (does not raise) when the database lookup blows up" do
    Organisation.stub :find_by_host, ->(_host) { raise ActiveRecord::StatementInvalid, "boom" } do
      request = stub_request("anything.test")
      assert_nothing_raised do
        assert_not @constraint.matches?(request)
      end
    end
  end

  private

  def stub_request(host)
    Struct.new(:host).new(host)
  end
end
