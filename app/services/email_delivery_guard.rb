class EmailDeliveryGuard
  EMAIL_TYPE_TOGGLES = {
    "order_confirmation" => :email_order_confirmation_enabled,
    "discount_notification" => :email_discount_notification_enabled,
  }.freeze

  AUTH_EMAILS = %w[reset_password team_invitation added_to_organisation].freeze

  def self.should_send?(organisation:, email_type:, customer: nil)
    return true if AUTH_EMAILS.include?(email_type.to_s)

    toggle = EMAIL_TYPE_TOGGLES[email_type.to_s]
    return true if toggle.nil?

    return false unless organisation.public_send(toggle)

    return false if customer.present? && !customer.email_notifications_enabled

    true
  end
end
