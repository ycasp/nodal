class CreateOrgMembers < ActiveRecord::Migration[7.1]
  def change
    create_table :org_members do |t|
      t.references :organisation, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.string :role
      t.datetime :joined_at
      t.boolean :active

      t.timestamps
    end
  end
end
