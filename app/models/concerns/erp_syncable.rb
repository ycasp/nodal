module ErpSyncable
  extend ActiveSupport::Concern

  included do
    scope :synced_from_erp, -> { where.not(external_id: nil) }
    scope :not_synced_from_erp, -> { where(external_id: nil) }
    scope :with_sync_errors, -> { where.not(sync_error: nil) }
    scope :sync_stale, ->(hours = 24) { where('last_synced_at < ?', hours.hours.ago) }
  end

  def synced_from_erp?
    external_id.present?
  end

  def has_sync_error?
    sync_error.present?
  end

  def sync_status
    return :not_synced unless synced_from_erp?
    return :error if has_sync_error?

    :synced
  end

  def mark_synced!(source:)
    update!(
      external_source: source,
      last_synced_at: Time.current,
      sync_error: nil
    )
  end

  def mark_sync_error!(error_message)
    update!(sync_error: error_message)
  end

  def clear_sync_error!
    update!(sync_error: nil)
  end

  class_methods do
    def find_by_external_id(external_id, source:)
      find_by(external_id: external_id, external_source: source)
    end
  end
end
