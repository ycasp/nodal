class AddCreatedByMemberIdToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_reference :customers, :created_by_member,
                  foreign_key: { to_table: :org_members },
                  null: true,
                  index: true
  end
end
