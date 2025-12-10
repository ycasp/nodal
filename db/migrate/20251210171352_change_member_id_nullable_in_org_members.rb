class ChangeMemberIdNullableInOrgMembers < ActiveRecord::Migration[7.1]
  def change
    change_column_null :org_members, :member_id, true
  end
end
