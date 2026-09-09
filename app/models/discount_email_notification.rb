class DiscountEmailNotification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :organisation
  belongs_to :sent_by, class_name: 'Member', optional: true

  scope :pending, -> { where(status: 'pending') }
  scope :sent, -> { where(status: 'sent') }

  def send_email!(member:)
    case notifiable_type
    when 'ProductDiscount', 'OrderDiscount'
      CustomerMailer.with(discount: notifiable, organisation: organisation).notify_clients_about_discount.deliver_later
    when 'CustomerDiscount', 'CustomerProductDiscount'
      CustomerMailer.with(discount: notifiable, organisation: organisation).notify_customer_about_discount.deliver_later
    when 'PromoCode'
      CustomerMailer.with(promo_code: notifiable, organisation: organisation).notify_promo_code.deliver_later
    end

    update!(status: 'sent', sent_at: Time.current, sent_by: member)
  end

  def self.recipient_count_for(notifiable, organisation)
    case notifiable
    when ProductDiscount, OrderDiscount
      organisation.customers.mailable.count
    when CustomerDiscount, CustomerProductDiscount
      if notifiable.category_based?
        notifiable.customer_category.customers.mailable.count
      else
        notifiable.customer&.mailable? ? 1 : 0
      end
    when PromoCode
      if notifiable.eligibility == 'all_customers'
        organisation.customers.mailable.count
      else
        customer_count = notifiable.eligible_customers.mailable.count
        if notifiable.eligible_customer_categories.any?
          category_count = Customer.mailable.where(
            customer_category_id: notifiable.eligible_customer_category_ids
          ).where.not(id: notifiable.eligible_customer_ids).count
          customer_count + category_count
        else
          customer_count
        end
      end
    else
      0
    end
  end
end
