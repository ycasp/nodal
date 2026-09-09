class AddStockPolicyToProductVariants < ActiveRecord::Migration[7.1]
  def up
    add_column :product_variants, :stock_policy, :string, default: 'inherit', null: false

    # Migrate data: hide_when_unavailable=false meant "show badge instead of hiding"
    execute <<-SQL
      UPDATE product_variants SET stock_policy = 'show_badge' WHERE hide_when_unavailable = false
    SQL

    remove_column :product_variants, :hide_when_unavailable
  end

  def down
    add_column :product_variants, :hide_when_unavailable, :boolean, default: true, null: false

    execute <<-SQL
      UPDATE product_variants SET hide_when_unavailable = false WHERE stock_policy = 'show_badge'
    SQL

    remove_column :product_variants, :stock_policy
  end
end
