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

        @sync_log = create_sync_log

        begin
          perform_sync
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
    end
  end
end
