module HasEmailNotification
  extend ActiveSupport::Concern

  included do
    has_one :email_notification, as: :notifiable, class_name: 'DiscountEmailNotification', dependent: :destroy
  end

  def email_pending?
    email_notification&.status == 'pending'
  end

  def email_sent?
    email_notification&.status == 'sent'
  end
end
