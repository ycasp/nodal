module Erp
  module Sync
    class BaseSyncService
      Result = Struct.new(:success?, :sync_log, :error, keyword_init: true)

      attr_reader :organisation, :erp_configuration, :adapter, :sync_log

      def initialize(organisation:, sync_type: 'manual')
        @organisation = organisation
        @erp_configuration = organisation.erp_configuration
        @adapter = erp_configuration&.adapter
        @sync_type = sync_type
      end

      def call
        return failure('ERP integration not configured') unless erp_configuration
        return failure('ERP integration not enabled') unless erp_configuration.enabled?
        return failure('Invalid adapter configuration') unless adapter

        # Clear zombie "running" logs from previously killed processes before
        # checking for concurrency, so the guard doesn't trip on stale state.
        cleanup_stale_logs

        if sync_already_running?
          return failure("A #{entity_type} sync is already running for this organisation")
        end

        @sync_log = create_sync_log

        begin
          perform_sync
          sync_log.save_change_details!
          sync_log.mark_completed!
          success
        rescue Erp::ApiError, Erp::ConnectionError => e
          sync_log.mark_failed!(e.message)
          failure(e.message)
        rescue StandardError => e
          Rails.logger.error "ERP Sync Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
          sync_log.mark_failed!(e.message)
          failure(e.message)
        end
      end

      protected

      def entity_type
        raise NotImplementedError, "#{self.class} must implement #entity_type"
      end

      def perform_sync
        raise NotImplementedError, "#{self.class} must implement #perform_sync"
      end

      def external_source
        erp_configuration.adapter_type
      end

      private

      def create_sync_log
        ErpSyncLog.start!(
          organisation: organisation,
          erp_configuration: erp_configuration,
          sync_type: @sync_type,
          entity_type: entity_type
        )
      end

      def success
        Result.new(success?: true, sync_log: sync_log, error: nil)
      end

      def failure(error_message)
        Result.new(success?: false, sync_log: sync_log, error: error_message)
      end

      # Mark zombie "running" logs (from killed processes) as completed.
      # Scoped to the same entity_type so a kill on one sync doesn't taint
      # logs of the others.
      def cleanup_stale_logs
        ErpSyncLog.where(
          organisation: organisation,
          entity_type: entity_type,
          status: 'running'
        ).where(started_at: ..10.minutes.ago)
         .find_each do |stale_log|
          stale_log.update(status: 'completed', completed_at: stale_log.updated_at)
        end
      rescue StandardError
        # Don't let cleanup errors break anything
      end

      def sync_already_running?
        ErpSyncLog.where(
          organisation: organisation,
          entity_type: entity_type,
          status: 'running'
        ).exists?
      end
    end
  end
end
