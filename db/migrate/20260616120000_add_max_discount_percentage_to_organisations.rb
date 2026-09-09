class AddMaxDiscountPercentageToOrganisations < ActiveRecord::Migration[7.1]
  def change
    # Stored as a fraction (0.40 = 40%). Null = no cap. Safety guardrail: the
    # total discount on an order can never exceed this, whatever combination of
    # line + order-level discounts applies.
    add_column :organisations, :max_discount_percentage, :decimal, precision: 5, scale: 4
  end
end
