class Bo::ErpSettingsController < Bo::BaseController
  skip_before_action :verify_authenticity_token, only: [:test_connection, :fetch_sample]
  before_action :set_erp_configuration

  def edit
    authorize @erp_configuration, policy_class: ErpSettingPolicy
    @available_adapters = Erp::AdapterRegistry.available_adapters
    @recent_sync_logs = @erp_configuration.erp_sync_logs.recent.limit(5) if @erp_configuration.persisted?
  end

  def update
    authorize @erp_configuration, policy_class: ErpSettingPolicy

    if @erp_configuration.update(erp_configuration_params)
      redirect_to edit_bo_erp_settings_path(org_slug: current_organisation.slug),
                  notice: "ERP settings updated successfully."
    else
      @available_adapters = Erp::AdapterRegistry.available_adapters
      render :edit, status: :unprocessable_entity
    end
  end

  def test_connection
    authorize @erp_configuration, policy_class: ErpSettingPolicy

    if @erp_configuration.adapter.nil?
      render json: { success: false, error: 'No adapter configured' }
      return
    end

    result = @erp_configuration.adapter.test_connection

    render json: result
  end

  def fetch_sample
    authorize @erp_configuration, policy_class: ErpSettingPolicy

    # Build a temporary adapter using credentials from the request params
    raw_credentials = fetch_sample_params[:credentials] || {}
    temp_credentials = raw_credentials.is_a?(Hash) ? raw_credentials.deep_symbolize_keys : {}
    adapter_type = fetch_sample_params[:adapter_type].presence || @erp_configuration.adapter_type || 'custom_api'

    adapter = Erp::AdapterRegistry.build(adapter_type, temp_credentials)

    unless adapter&.valid_credentials?
      render json: { success: false, error: 'Missing required credentials' }
      return
    end

    result = { success: true, products: nil, customers: nil }

    begin
      if fetch_sample_params[:fetch_products] != 'false'
        result[:products] = adapter.fetch_sample_product
      end
    rescue => e
      result[:products_error] = e.message
    end

    begin
      if fetch_sample_params[:fetch_customers] != 'false'
        result[:customers] = adapter.fetch_sample_customer
      end
    rescue => e
      result[:customers_error] = e.message
    end

    # Fetch order/order_item table samples for adapters that support push
    if adapter.supports_push?
      begin
        result[:orders] = adapter.fetch_sample_order if adapter.respond_to?(:fetch_sample_order)
      rescue => e
        result[:orders_error] = e.message
      end

      begin
        result[:order_items] = adapter.fetch_sample_order_item if adapter.respond_to?(:fetch_sample_order_item)
      rescue => e
        result[:order_items_error] = e.message
      end
    end

    render json: result
  end

  def sync_now
    authorize @erp_configuration, policy_class: ErpSettingPolicy

    unless @erp_configuration.can_sync?
      redirect_to edit_bo_erp_settings_path(org_slug: current_organisation.slug),
                  alert: "Cannot sync: ERP integration is not properly configured."
      return
    end

    # Run in a background thread so the response returns immediately
    # (avoids Heroku's 30-second request timeout on large datasets)
    org_id = current_organisation.id
    Thread.new do
      Rails.application.executor.wrap do
        ErpSyncJob.perform_now(org_id, sync_type: 'manual')
      end
    end

    redirect_to edit_bo_erp_settings_path(org_slug: current_organisation.slug),
                notice: "Sync started. Refresh the page to check progress."
  end

  def sync_logs
    authorize @erp_configuration, policy_class: ErpSettingPolicy

    @sync_logs = current_organisation.erp_sync_logs.recent.limit(50)
  end

  private

  def set_erp_configuration
    @erp_configuration = current_organisation.erp_configuration ||
                         current_organisation.build_erp_configuration
  end

  def erp_configuration_params
    params.require(:erp_configuration).permit(
      :enabled,
      :adapter_type,
      :sync_products,
      :sync_customers,
      :sync_orders,
      :sync_frequency,
      :product_sync_mode
    ).tap do |p|
      # Handle credentials separately to support nested field_mappings
      if params[:erp_configuration][:credentials].present?
        credentials_params = params[:erp_configuration][:credentials]
        credentials = extract_credentials(credentials_params)
        @erp_configuration.credentials = credentials
      end
    end
  end

  def extract_credentials(credentials_params)
    credentials = {}

    # Dynamically extract credential fields from the adapter's schema
    adapter_type = params.dig(:erp_configuration, :adapter_type) || @erp_configuration.adapter_type
    schema = Erp::AdapterRegistry.credentials_schema(adapter_type)

    schema.each_key do |key|
      str_key = key.to_s
      credentials[str_key] = credentials_params[str_key] if credentials_params[str_key].present?
    end

    # Also allow auth_type (used by custom_api but not in schema)
    credentials['auth_type'] = credentials_params['auth_type'] if credentials_params['auth_type'].present?

    # Extract nested field_mappings
    if credentials_params[:field_mappings].present?
      field_mappings = {}
      %w[products customers orders order_items].each do |entity|
        mapping = extract_field_mapping(credentials_params.dig(:field_mappings, entity.to_sym) || credentials_params.dig(:field_mappings, entity))
        field_mappings[entity] = mapping if mapping.present?
      end
      credentials['field_mappings'] = field_mappings if field_mappings.any?
    end

    credentials
  end

  def extract_field_mapping(mapping_params)
    return {} if mapping_params.blank?

    # Convert to hash and remove empty values
    mapping_params.to_unsafe_h.transform_values(&:presence).compact
  end

  def fetch_sample_params
    result = params.permit(:fetch_products, :fetch_customers, :adapter_type).to_h
    # Handle credentials hash separately to allow arbitrary keys
    if params[:credentials].present?
      result[:credentials] = params[:credentials].to_unsafe_h
    end
    result.with_indifferent_access
  end
end
