class BackfillSpecialPriceCardToggles < ActiveRecord::Migration[7.1]
  def up
    %i[special_prices_show_price special_prices_show_discount_badge special_prices_show_sale_badge].each do |col|
      change_column_default :organisations, col, true
      execute "UPDATE organisations SET #{col} = TRUE WHERE #{col} IS NULL"
      change_column_null :organisations, col, false
    end
  end

  def down
    %i[special_prices_show_price special_prices_show_discount_badge special_prices_show_sale_badge].each do |col|
      change_column_null :organisations, col, true
      change_column_default :organisations, col, nil
    end
  end
end
