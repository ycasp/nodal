class ErpSyncLog < ApplicationRecord
  SYNC_TYPES = %w[full incremental manual].freeze
  ENTITY_TYPES = %w[products customers].freeze
  STATUSES = %w[running completed failed].freeze

  belongs_to :organisation
  belongs_to :erp_configuration

  validates :sync_type, inclusion: { in: SYNC_TYPES }
  validates :entity_type, inclusion: { in: ENTITY_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :for_entity, ->(entity_type) { where(entity_type: entity_type) }

  def self.start!(organisation:, erp_configuration:, sync_type:, entity_type:)
    create!(
      organisation: organisation,
      erp_configuration: erp_configuration,
      sync_type: sync_type,
      entity_type: entity_type,
      status: 'running',
      started_at: Time.current
    )
  end

  def running?
    status == 'running'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def duration
    return nil unless started_at

    end_time = completed_at || Time.current
    end_time - started_at
  end

  def duration_in_words
    return nil unless duration

    if duration < 60
      "#{duration.round} seconds"
    elsif duration < 3600
      "#{(duration / 60).round} minutes"
    else
      "#{(duration / 3600).round(1)} hours"
    end
  end

  def add_error(record_identifier, error_message)
    self.error_details ||= []
    self.error_details << { record: record_identifier, error: error_message, at: Time.current.iso8601 }
  end

  def increment_processed!
    increment!(:records_processed)
  end

  def increment_created!
    increment!(:records_created)
    increment!(:records_processed)
  end

  def increment_updated!
    increment!(:records_updated)
    increment!(:records_processed)
  end

  def increment_failed!(record_identifier = nil, error_message = nil)
    increment!(:records_failed)
    increment!(:records_processed)
    add_error(record_identifier, error_message) if record_identifier
    save! if record_identifier
  end

  def mark_completed!(summary_text = nil)
    update!(
      status: 'completed',
      completed_at: Time.current,
      summary: summary_text || generate_summary
    )
  end

  def mark_failed!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      summary: "Sync failed: #{error_message}"
    )
  end

  def success_rate
    return 0 if records_processed.zero?

    ((records_processed - records_failed).to_f / records_processed * 100).round(1)
  end

  private

  def generate_summary
    parts = []
    parts << "Created: #{records_created}" if records_created.positive?
    parts << "Updated: #{records_updated}" if records_updated.positive?
    parts << "Failed: #{records_failed}" if records_failed.positive?
    parts << "Total processed: #{records_processed}"
    parts.join(', ')
  end
end
