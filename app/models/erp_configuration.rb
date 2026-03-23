class ErpConfiguration < ApplicationRecord
  ADAPTER_TYPES = %w[custom_api firebird].freeze
  SYNC_FREQUENCIES = %w[hourly daily weekly manual].freeze
  SYNC_STATUSES = %w[success partial failed].freeze
  PRODUCT_SYNC_MODES = %w[update_only full_sync].freeze

  belongs_to :organisation
  has_many :erp_sync_logs, dependent: :destroy

  encrypts :credentials_ciphertext

  validates :adapter_type, inclusion: { in: ADAPTER_TYPES }, allow_blank: true
  validates :sync_frequency, inclusion: { in: SYNC_FREQUENCIES }
  validates :last_sync_status, inclusion: { in: SYNC_STATUSES }, allow_blank: true
  validates :product_sync_mode, inclusion: { in: PRODUCT_SYNC_MODES }
  validate :validate_credentials_format, if: :enabled?

  def credentials
    return {} if credentials_ciphertext.blank?

    JSON.parse(credentials_ciphertext)
  rescue JSON::ParserError
    {}
  end

  def credentials=(hash)
    self.credentials_ciphertext = hash.to_json
  end

  def adapter
    return nil unless adapter_type.present?

    Erp::AdapterRegistry.build(adapter_type, credentials)
  end

  def full_product_sync?
    product_sync_mode == 'full_sync'
  end

  def can_sync?
    enabled? && adapter_type.present? && adapter.present?
  end

  def can_sync_products?
    can_sync? && sync_products?
  end

  def can_sync_customers?
    can_sync? && sync_customers?
  end

  def can_sync_orders?
    can_sync? && sync_orders?
  end

  def mark_sync_success!
    update!(
      last_sync_at: Time.current,
      last_sync_status: 'success',
      last_sync_error: nil
    )
  end

  def mark_sync_partial!(error_message = nil)
    update!(
      last_sync_at: Time.current,
      last_sync_status: 'partial',
      last_sync_error: error_message
    )
  end

  def mark_sync_failed!(error_message)
    update!(
      last_sync_at: Time.current,
      last_sync_status: 'failed',
      last_sync_error: error_message
    )
  end

  def sync_due?
    return false if sync_frequency == 'manual'
    return true if last_sync_at.nil?

    case sync_frequency
    when 'hourly'
      last_sync_at < 1.hour.ago
    when 'daily'
      last_sync_at < 1.day.ago
    when 'weekly'
      last_sync_at < 1.week.ago
    else
      false
    end
  end

  private

  def validate_credentials_format
    return if adapter_type.blank?

    required_keys = Erp::AdapterRegistry.required_credentials(adapter_type)
    creds = credentials

    missing_keys = required_keys - creds.keys.map(&:to_s)
    if missing_keys.any?
      errors.add(:credentials_ciphertext, "missing required fields: #{missing_keys.join(', ')}")
    end
  end
end
