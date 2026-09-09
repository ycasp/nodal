class AddIsSalesRepToOrgMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :org_members, :is_sales_rep, :boolean, default: false, null: false

    add_index :org_members, [:organisation_id, :is_sales_rep],
              where: "is_sales_rep = true",
              name: "index_org_members_on_org_id_sales_reps"
  end
end
