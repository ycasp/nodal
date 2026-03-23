class AddTermsAcceptedAtToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :terms_accepted_at, :datetime
  end
end
