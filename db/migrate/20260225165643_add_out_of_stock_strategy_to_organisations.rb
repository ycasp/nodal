class AddOutOfStockStrategyToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :out_of_stock_strategy, :string, default: 'do_nothing', null: false
    change_column_default :product_variants, :track_stock, from: false, to: true
  end
end
