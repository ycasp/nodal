module Erp
  class AdapterRegistry
    ADAPTERS = {
      'custom_api' => {
        class_name: 'Erp::Adapters::CustomApiAdapter',
        display_name: 'Custom REST API',
        description: 'Generic REST API adapter for custom ERP integrations',
        credentials: {
          base_url: { label: 'API Base URL', type: :url, required: true, placeholder: 'https://api.example.com' },
          api_key: { label: 'API Key', type: :password, required: true, placeholder: 'Your API key' },
          products_endpoint: { label: 'Products Endpoint', type: :text, required: false, placeholder: '/products', default: '/products' },
          customers_endpoint: { label: 'Customers Endpoint', type: :text, required: false, placeholder: '/customers', default: '/customers' }
        }
      }
    }.freeze

    class << self
      def build(adapter_type, credentials)
        config = ADAPTERS[adapter_type]
        return nil unless config

        adapter_class = config[:class_name].constantize
        adapter_class.new(credentials)
      rescue NameError => e
        Rails.logger.error "Failed to load adapter class: #{e.message}"
        nil
      end

      def available_adapters
        ADAPTERS.map do |key, config|
          {
            key: key,
            display_name: config[:display_name],
            description: config[:description]
          }
        end
      end

      def adapter_config(adapter_type)
        ADAPTERS[adapter_type]
      end

      def credentials_schema(adapter_type)
        ADAPTERS.dig(adapter_type, :credentials) || {}
      end

      def required_credentials(adapter_type)
        schema = credentials_schema(adapter_type)
        schema.select { |_, config| config[:required] }.keys.map(&:to_s)
      end

      def valid_adapter_type?(adapter_type)
        ADAPTERS.key?(adapter_type)
      end
    end
  end
end
