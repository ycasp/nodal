class AddInvitationFieldsToOrgMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :org_members, :invitation_token, :string
    add_index :org_members, :invitation_token, unique: true
    add_column :org_members, :invitation_sent_at, :datetime
    add_column :org_members, :invited_by_id, :bigint
    add_column :org_members, :invitation_accepted_at, :datetime
    add_column :org_members, :invited_email, :string
  end
end
