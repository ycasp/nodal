class MakeQuickAccessTokenTtlDaysNullable < ActiveRecord::Migration[7.1]
  # Allow nil to mean "tokens never expire" — the merchant clears the
  # field in BO Settings to opt out of expiration. The model treats nil
  # as 100 years and the badge shows "Sem expiração" instead of a date.
  def change
    change_column_null :organisations, :quick_access_token_ttl_days, true
  end
end
