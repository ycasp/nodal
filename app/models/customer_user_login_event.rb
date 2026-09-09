class CustomerUserLoginEvent < ApplicationRecord
  belongs_to :customer_user, optional: true
  belongs_to :organisation

  METHODS = %w[
    password
    qr_landing
    qr_password
    pin
    qr_pin
    passkey
    qr_passkey
    cross_device
  ].freeze

  validates :method, presence: true, inclusion: { in: METHODS }
  validates :success, inclusion: { in: [true, false] }

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
end
