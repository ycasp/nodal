require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "export login_emails column joins the customer's login emails" do
    org = Organisation.create!(name: "Export Org")
    customer = Customer.create!(organisation: org, company_name: "Acme", contact_name: "J", active: true)
    CustomerUser.create!(organisation: org, customer: customer, email: "a@acme.test",
      password: "password123", password_confirmation: "password123", contact_name: "A", active: true)
    CustomerUser.create!(organisation: org, customer: customer, email: "b@acme.test",
      password: "password123", password_confirmation: "password123", contact_name: "B", active: true)

    col = Customer.exportable_columns.find { |c| c[:key] == :login_emails }
    assert col, "login_emails export column should exist"
    assert col[:default], "login_emails should be exported by default"
    assert_equal "a@acme.test; b@acme.test", col[:value].call(customer.reload)

    # The legacy Customer#email orphan column is no longer a default export.
    email_col = Customer.exportable_columns.find { |c| c[:key] == :email }
    assert_not email_col[:default]
  end

  # The ERP has no email for a large slice of the customer base. Before the
  # partial unique index, the second one of these hit PG::UniqueViolation on
  # ("", organisation_id) and failed on every single sync.
  test "many customers without an email can coexist in the same organisation" do
    org = Organisation.create!(name: "No Email Org")

    first  = Customer.create!(organisation: org, company_name: "Alfa", contact_name: "A", active: true)
    second = Customer.create!(organisation: org, company_name: "Beta", contact_name: "B", active: true)

    assert first.missing_email?
    assert second.missing_email?
    assert_equal [first.id, second.id].sort, org.customers.without_email.pluck(:id).sort
  end

  test "a real email is still unique per organisation" do
    org = Organisation.create!(name: "Unique Email Org")
    Customer.create!(organisation: org, company_name: "Alfa", contact_name: "A",
      active: true, email: "dup@acme.test")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Customer.create!(organisation: org, company_name: "Beta", contact_name: "B",
        active: true, email: "dup@acme.test")
    end
  end

  # Rep-only shells: an empresa with no email still needs a CustomerUser,
  # because orders.customer_user_id is NOT NULL and the rep sells by
  # impersonation.
  test "seed_stub_customer_user creates a login for a customer with no email" do
    org = Organisation.create!(name: "Stub Org")
    alfa = Customer.create!(organisation: org, company_name: "Alfa", contact_name: "A", active: true)
    beta = Customer.create!(organisation: org, company_name: "Beta", contact_name: "B", active: true)

    alfa.seed_stub_customer_user
    beta.seed_stub_customer_user

    assert_equal 1, alfa.customer_users.count
    assert_equal 1, beta.customer_users.count
  end

  test "a login with no email can never authenticate" do
    org = Organisation.create!(name: "Shell Login Org")
    customer = Customer.create!(organisation: org, company_name: "Alfa", contact_name: "A", active: true)
    customer.seed_stub_customer_user

    assert_not customer.customer_users.first.active_for_authentication?
  end
end
