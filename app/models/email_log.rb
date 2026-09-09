class EmailLog < ApplicationRecord
  belongs_to :organisation
  belongs_to :customer, optional: true
  belongs_to :member, optional: true

  validates :email_type, :mailer_class, :recipient_email, :status, presence: true

  scope :recent, -> { order(sent_at: :desc) }
  scope :failed, -> { where(status: "failed") }
  scope :skipped, -> { where(status: "skipped") }
  scope :for_customer, ->(customer) { where(customer: customer) }
end
