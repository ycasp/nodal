module Erp
  module Adapters
    class CustomApiAdapter < BaseAdapter
      def valid_credentials?
        credentials[:base_url].present? && credentials[:api_key].present?
      end

      def test_connection
        return { success: false, error: 'Missing credentials' } unless valid_credentials?

        response = http_client.get(products_url) do |req|
          apply_auth(req)
        end

        { success: true, message: 'Connection successful' }
      rescue Faraday::Error => e
        { success: false, error: extract_error_message(e) }
      end

      def fetch_products
        return [] unless valid_credentials?

        response = http_client.get(products_url) do |req|
          apply_auth(req)
        end

        normalize_products(response.body)
      rescue Faraday::Error => e
        handle_request_error(e)
      end

      def fetch_customers
        return [] unless valid_credentials?

        response = http_client.get(customers_url) do |req|
          apply_auth(req)
        end

        normalize_customers(response.body)
      rescue Faraday::Error => e
        handle_request_error(e)
      end

      # Fetch a single raw product for field mapping UI
      def fetch_sample_product
        return nil unless valid_credentials?

        response = http_client.get(products_url) do |req|
          apply_auth(req)
        end

        data = extract_data(response.body)
        return nil if data.empty?

        # Return the first item with its fields and sample values
        sample = data.first
        {
          fields: extract_field_info(sample)
        }
      rescue Faraday::Error => e
        raise "Failed to fetch products: #{extract_error_message(e)}"
      end

      # Fetch a single raw customer for field mapping UI
      def fetch_sample_customer
        return nil unless valid_credentials?

        response = http_client.get(customers_url) do |req|
          apply_auth(req)
        end

        data = extract_data(response.body)
        return nil if data.empty?

        # Return the first item with its fields and sample values
        sample = data.first
        {
          fields: extract_field_info(sample)
        }
      rescue Faraday::Error => e
        raise "Failed to fetch customers: #{extract_error_message(e)}"
      end

      private

      # Extract field names and sample values from a raw item
      def extract_field_info(item, prefix = '')
        fields = []

        item.each do |key, value|
          field_path = prefix.present? ? "#{prefix}.#{key}" : key.to_s

          if value.is_a?(Hash)
            # Recursively extract nested fields
            fields.concat(extract_field_info(value, field_path))
          elsif value.is_a?(Array)
            # For arrays, just note the type
            fields << { key: field_path, value: "[Array with #{value.length} items]", type: 'array' }
          else
            fields << { key: field_path, value: truncate_value(value), type: value_type(value) }
          end
        end

        fields
      end

      def truncate_value(value)
        str = value.to_s
        str.length > 50 ? "#{str[0..47]}..." : str
      end

      def value_type(value)
        case value
        when Integer then 'integer'
        when Float then 'float'
        when TrueClass, FalseClass then 'boolean'
        when NilClass then 'null'
        else 'string'
        end
      end

      def base_url
        credentials[:base_url].to_s.chomp('/')
      end

      def products_endpoint
        credentials[:products_endpoint].presence || '/products'
      end

      def customers_endpoint
        credentials[:customers_endpoint].presence || '/customers'
      end

      def products_url
        "#{base_url}#{products_endpoint}"
      end

      def customers_url
        "#{base_url}#{customers_endpoint}"
      end

      def apply_auth(request)
        api_key = credentials[:api_key]

        if credentials[:auth_type] == 'bearer'
          request.headers['Authorization'] = "Bearer #{api_key}"
        else
          request.headers['X-API-Key'] = api_key
        end
      end

      def normalize_products(body)
        data = extract_data(body)
        data.map { |item| normalize_product(item) }
      end

      def normalize_product(item)
        mappings = product_field_mappings

        {
          external_id: get_mapped_value(item, mappings, :external_id, ['id'])&.to_s,
          name: get_mapped_value(item, mappings, :name, ['name', 'title', 'product_name']),
          sku: get_mapped_value(item, mappings, :sku, ['sku', 'code', 'product_code']),
          description: get_mapped_value(item, mappings, :description, ['description', 'desc']),
          unit_price_cents: parse_price(get_mapped_value(item, mappings, :unit_price, ['price', 'unit_price'])),
          available: parse_boolean(get_mapped_value(item, mappings, :available, ['available', 'active', 'enabled']) || true),
          raw_data: item
        }.compact
      end

      def normalize_customers(body)
        data = extract_data(body)
        data.map { |item| normalize_customer(item) }
      end

      def normalize_customer(item)
        mappings = customer_field_mappings

        {
          external_id: get_mapped_value(item, mappings, :external_id, ['id'])&.to_s,
          company_name: get_mapped_value(item, mappings, :company_name, ['company_name', 'company', 'name']),
          contact_name: get_mapped_value(item, mappings, :contact_name, ['contact_name', 'contact', 'primary_contact']),
          email: get_mapped_value(item, mappings, :email, ['email', 'contact_email']),
          phone: get_mapped_value(item, mappings, :contact_phone, ['phone', 'telephone', 'contact_phone']),
          active: parse_boolean(get_mapped_value(item, mappings, :active, ['active', 'enabled']) || true),
          raw_data: item
        }.compact
      end

      def extract_data(body)
        return body if body.is_a?(Array)
        return body['data'] if body.is_a?(Hash) && body['data'].is_a?(Array)
        return body['items'] if body.is_a?(Hash) && body['items'].is_a?(Array)
        return body['results'] if body.is_a?(Hash) && body['results'].is_a?(Array)

        []
      end

      # Get field mappings from credentials
      def product_field_mappings
        mappings = credentials.dig(:field_mappings, :products) ||
                   credentials.dig('field_mappings', 'products') || {}
        mappings.transform_keys(&:to_sym)
      end

      def customer_field_mappings
        mappings = credentials.dig(:field_mappings, :customers) ||
                   credentials.dig('field_mappings', 'customers') || {}
        mappings.transform_keys(&:to_sym)
      end

      # Get a value from an item using configured mapping or default keys
      def get_mapped_value(item, mappings, nodal_field, default_keys)
        # First, try the configured mapping
        mapped_key = mappings[nodal_field]
        if mapped_key.present?
          return dig_nested_value(item, mapped_key)
        end

        # Fall back to trying each default key
        default_keys.each do |key|
          value = dig_nested_value(item, key)
          return value if value.present?
        end

        nil
      end

      # Support nested field paths like "customer.address.city"
      def dig_nested_value(item, key_path)
        keys = key_path.to_s.split('.')
        value = item

        keys.each do |key|
          return nil unless value.is_a?(Hash)
          # Try both string and symbol keys
          value = value[key] || value[key.to_sym]
          return nil if value.nil?
        end

        value
      end

      def parse_price(value)
        return nil if value.nil?

        case value
        when Integer
          value
        when Float
          (value * 100).round
        when String
          (value.to_f * 100).round
        else
          nil
        end
      end

      def parse_boolean(value)
        return true if value.nil?
        return value if [true, false].include?(value)
        return true if value.to_s.downcase.in?(%w[true 1 yes active enabled])

        false
      end

      def extract_error_message(error)
        case error
        when Faraday::ConnectionFailed
          "Could not connect to #{base_url}"
        when Faraday::TimeoutError
          "Connection timed out"
        when Faraday::ClientError
          status = error.response&.dig(:status) || 'unknown'
          "API returned status #{status}"
        else
          error.message
        end
      end
    end
  end
end
