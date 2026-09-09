class ErpSyncJob < ApplicationJob
  queue_as :erp_sync

  retry_on Erp::ConnectionError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(organisation_id, sync_type: 'manual', entity_types: nil)
    organisation = Organisation.find(organisation_id)
    erp_config = organisation.erp_configuration

    return unless erp_config&.can_sync?

    entity_types ||= determine_entity_types(erp_config)
    results = []

    entity_types.each do |entity_type|
      result = sync_entity(organisation, entity_type, sync_type)
      results << result
    end

    update_configuration_status(erp_config, results)
  end

  private

  def determine_entity_types(erp_config)
    types = []
    types << 'products' if erp_config.sync_products?
    types << 'customers' if erp_config.sync_customers?
    types << 'orders' if erp_config.sync_orders?
    types
  end

  def sync_entity(organisation, entity_type, sync_type)
    service_class = case entity_type
    when 'products'
      Erp::Sync::ProductSyncService
    when 'customers'
      Erp::Sync::CustomerSyncService
    when 'orders'
      Erp::Sync::OrderExportService
    else
      return nil
    end

    service_class.new(organisation: organisation, sync_type: sync_type).call
  end

  def update_configuration_status(erp_config, results)
    valid_results = results.compact

    if valid_results.empty?
      return
    end

    all_successful = valid_results.all?(&:success?)
    any_successful = valid_results.any?(&:success?)

    if all_successful
      erp_config.mark_sync_success!
    elsif any_successful
      failed_results = valid_results.reject(&:success?)
      errors = failed_results.map(&:error).join('; ')
      erp_config.mark_sync_partial!(errors)
    else
      errors = valid_results.map(&:error).join('; ')
      erp_config.mark_sync_failed!(errors)
    end
  end
end
