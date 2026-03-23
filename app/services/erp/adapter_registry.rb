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
      },
      'firebird' => {
        class_name: 'Erp::Adapters::FirebirdAdapter',
        display_name: 'Firebird Database',
        description: 'Direct connection to a Firebird 2.5 database (no API needed)',
        credentials: {
          host: { label: 'Database Host', type: :text, required: true, placeholder: '192.168.1.100' },
          port: { label: 'Port', type: :text, required: false, placeholder: '3050', default: '3050' },
          database_path: { label: 'Database Path', type: :text, required: true, placeholder: '/path/to/database.fdb' },
          username: { label: 'Username', type: :text, required: true, placeholder: 'SYSDBA', default: 'SYSDBA' },
          password: { label: 'Password', type: :password, required: true, placeholder: 'Database password' },
          products_table: { label: 'Products Table', type: :text, required: false, placeholder: 'PRODUCTS', default: 'PRODUCTS' },
          customers_table: { label: 'Customers Table', type: :text, required: false, placeholder: 'CUSTOMERS', default: 'CUSTOMERS' },
          orders_table: { label: 'Orders Table', type: :text, required: false, placeholder: 'ORDERS', default: 'ORDERS' },
          order_items_table: { label: 'Order Items Table', type: :text, required: false, placeholder: 'ORDER_ITEMS', default: 'ORDER_ITEMS' },
          encoding: { label: 'Character Encoding', type: :text, required: false, placeholder: 'WIN1252', default: 'WIN1252' }
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
