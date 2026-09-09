class AllowMultipleCustomersWithoutEmail < ActiveRecord::Migration[7.1]
  # Both `customers.email` and `customer_users.email` carry a plain unique index
  # left over from when Customer was the Devise model. After the Customer /
  # CustomerUser split the login email lives on customer_users, and
  # Customer#email is just an ERP mirror — but both columns are NOT NULL with
  # default "", so every record the ERP has no email for collides on
  # ("", organisation_id) and only the first one can ever exist.
  #
  # That is what fails ~309 rows on every customer sync with
  # PG::UniqueViolation, and what stops a rep from impersonating an empresa
  # that has no login yet (orders.customer_user_id is NOT NULL, so the cart
  # needs a CustomerUser to hang on).
  #
  # Same shape the taxpayer_id and product_variants.sku indexes already use:
  # keep uniqueness for real addresses, exempt the blanks. Blank stays "" —
  # the column keeps its NOT NULL/default "" so every existing `email.blank?`
  # / `email.present?` guard behaves exactly as before.
  def up
    remove_index :customers, name: "index_customers_on_email_and_organisation_id"
    add_index :customers, %i[email organisation_id],
              name: "index_customers_on_email_and_organisation_id",
              unique: true,
              where: "email <> ''"

    remove_index :customer_users, name: "index_customer_users_on_email_and_organisation_id"
    add_index :customer_users, %i[email organisation_id],
              name: "index_customer_users_on_email_and_organisation_id",
              unique: true,
              where: "email <> ''"
  end

  # Rolling back raises once more than one blank-email row exists per org —
  # correctly so: the old constraint no longer fits the data. Clean up the
  # blanks first if you really need to go back.
  def down
    remove_index :customer_users, name: "index_customer_users_on_email_and_organisation_id"
    add_index :customer_users, %i[email organisation_id],
              name: "index_customer_users_on_email_and_organisation_id",
              unique: true

    remove_index :customers, name: "index_customers_on_email_and_organisation_id"
    add_index :customers, %i[email organisation_id],
              name: "index_customers_on_email_and_organisation_id",
              unique: true
  end
end
