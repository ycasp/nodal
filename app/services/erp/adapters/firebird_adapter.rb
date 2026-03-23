module Erp
  module Adapters
    class FirebirdAdapter < BaseAdapter
      IDENTIFIER_PATTERN = /\A[A-Za-z_][A-Za-z0-9_\$]{0,30}\z/

      # Map Firebird charset names to Ruby encoding names
      ENCODING_MAP = {
        'WIN1252' => 'Windows-1252',
        'WIN1250' => 'Windows-1250',
        'WIN1251' => 'Windows-1251',
        'WIN1253' => 'Windows-1253',
        'WIN1254' => 'Windows-1254',
        'ISO8859_1' => 'ISO-8859-1',
        'ISO8859_15' => 'ISO-8859-15',
        'UTF8' => 'UTF-8',
        'NONE' => 'ASCII-8BIT'
      }.freeze

      def self.fb_available?
        require 'fb'
        true
      rescue LoadError
        false
      end

      def valid_credentials?
        credentials[:host].present? &&
          credentials[:database_path].present? &&
          credentials[:username].present? &&
          credentials[:password].present?
      end

      def test_connection
        return { success: false, error: 'Missing credentials' } unless valid_credentials?
        return { success: false, error: 'Firebird client library (fb gem) is not installed' } unless self.class.fb_available?

        with_connection do |db|
          # Simple query to verify the connection works
          db.query("SELECT 1 FROM RDB$DATABASE")
        end

        { success: true, message: 'Connection successful' }
      rescue => e
        { success: false, error: friendly_error(e) }
      end

      def fetch_products
        return [] unless valid_credentials?

        rows = with_connection do |db|
          query_as_hashes(db, "SELECT * FROM #{safe_table_name(products_table)}")
        end

        rows.map { |row| normalize_product(normalize_row(row)) }
      rescue => e
        raise_erp_error(e)
      end

      def fetch_customers
        return [] unless valid_credentials?

        rows = with_connection do |db|
          query_as_hashes(db, "SELECT * FROM #{safe_table_name(customers_table)}")
        end

        rows.map { |row| normalize_customer(normalize_row(row)) }
      rescue => e
        raise_erp_error(e)
      end

      def fetch_sample_product
        return nil unless valid_credentials?

        row = with_connection do |db|
          query_as_hashes(db, "SELECT FIRST 1 * FROM #{safe_table_name(products_table)}").first
        end

        return nil unless row

        { fields: extract_field_info(row) }
      rescue => e
        raise "Failed to fetch products: #{friendly_error(e)}"
      end

      def fetch_sample_customer
        return nil unless valid_credentials?

        row = with_connection do |db|
          query_as_hashes(db, "SELECT FIRST 1 * FROM #{safe_table_name(customers_table)}").first
        end

        return nil unless row

        { fields: extract_field_info(row) }
      rescue => e
        raise "Failed to fetch customers: #{friendly_error(e)}"
      end

      def fetch_sample_order
        return nil unless valid_credentials?

        row = with_connection do |db|
          query_as_hashes(db, "SELECT FIRST 1 * FROM #{safe_table_name(orders_table)}").first
        end

        return nil unless row

        { fields: extract_field_info(row) }
      rescue => e
        raise "Failed to fetch orders: #{friendly_error(e)}"
      end

      def fetch_sample_order_item
        return nil unless valid_credentials?

        row = with_connection do |db|
          query_as_hashes(db, "SELECT FIRST 1 * FROM #{safe_table_name(order_items_table)}").first
        end

        return nil unless row

        { fields: extract_field_info(row) }
      rescue => e
        raise "Failed to fetch order items: #{friendly_error(e)}"
      end

      def supports_push?
        true
      end

      def push_order(order_data)
        return { success: false, error: 'Missing credentials' } unless valid_credentials?

        mappings = order_field_mappings
        item_mappings = order_item_field_mappings

        with_connection do |db|
          db.transaction do
            # Insert order header
            order_columns = []
            order_values = []

            mappings.each do |nodal_field, erp_column|
              next if erp_column.blank?
              next unless order_data.key?(nodal_field.to_s) || order_data.key?(nodal_field.to_sym)

              order_columns << safe_column_name(erp_column)
              order_values << order_data[nodal_field.to_s] || order_data[nodal_field.to_sym]
            end

            if order_columns.any?
              placeholders = order_columns.map { '?' }.join(', ')
              sql = "INSERT INTO #{safe_table_name(orders_table)} (#{order_columns.join(', ')}) VALUES (#{placeholders})"
              db.execute(sql, *encode_values(order_values))
            end

            # Insert order items
            (order_data['items'] || order_data[:items] || []).each do |item_data|
              item_columns = []
              item_values = []

              item_mappings.each do |nodal_field, erp_column|
                next if erp_column.blank?
                next unless item_data.key?(nodal_field.to_s) || item_data.key?(nodal_field.to_sym)

                item_columns << safe_column_name(erp_column)
                item_values << item_data[nodal_field.to_s] || item_data[nodal_field.to_sym]
              end

              if item_columns.any?
                placeholders = item_columns.map { '?' }.join(', ')
                sql = "INSERT INTO #{safe_table_name(order_items_table)} (#{item_columns.join(', ')}) VALUES (#{placeholders})"
                db.execute(sql, *encode_values(item_values))
              end
            end
          end
        end

        { success: true }
      rescue => e
        raise_erp_error(e)
      end

      private

      # Connection management — opens and closes per operation to avoid stale connections
      def with_connection
        raise Erp::ConnectionError, "Firebird client library (fb gem) is not installed" unless self.class.fb_available?

        port = credentials[:port].presence || '3050'
        connection_string = "#{credentials[:host]}/#{port}:#{credentials[:database_path]}"

        db = Fb::Database.new(
          database: connection_string,
          username: credentials[:username],
          password: credentials[:password],
          charset: encoding
        ).connect

        yield db
      ensure
        db&.close
      end

      # Execute a query and return rows as hashes with column names as keys
      def query_as_hashes(db, sql)
        cursor = db.execute(sql)
        columns = cursor.fields.map { |f| f.name.to_s }
        rows = []
        while (row = cursor.fetch)
          hash = {}
          columns.each_with_index { |col, i| hash[col] = row[i] }
          rows << hash
        end
        rows
      ensure
        cursor&.close
      end

      # Table/column names
      def products_table
        credentials[:products_table].presence || 'PRODUCTS'
      end

      def customers_table
        credentials[:customers_table].presence || 'CUSTOMERS'
      end

      def orders_table
        credentials[:orders_table].presence || 'ORDERS'
      end

      def order_items_table
        credentials[:order_items_table].presence || 'ORDER_ITEMS'
      end

      # Firebird charset name (used for connection)
      def encoding
        credentials[:encoding].presence || 'WIN1252'
      end

      # Ruby encoding name (used for string conversion)
      def ruby_encoding
        ENCODING_MAP[encoding.upcase] || encoding
      end

      # Apply field mappings to convert raw Firebird rows into Nodal format
      def normalize_product(row)
        mappings = product_field_mappings

        {
          external_id: get_mapped_value(row, mappings, :external_id)&.to_s,
          name: get_mapped_value(row, mappings, :name),
          sku: get_mapped_value(row, mappings, :sku),
          description: get_mapped_value(row, mappings, :description),
          unit_price_cents: parse_price(get_mapped_value(row, mappings, :unit_price)),
          available: parse_boolean(get_mapped_value(row, mappings, :available)),
          stock_quantity: parse_integer(get_mapped_value(row, mappings, :stock_quantity)),
          raw_data: row
        }.compact
      end

      def normalize_customer(row)
        mappings = customer_field_mappings

        {
          external_id: get_mapped_value(row, mappings, :external_id)&.to_s,
          company_name: get_mapped_value(row, mappings, :company_name),
          contact_name: get_mapped_value(row, mappings, :contact_name),
          email: get_mapped_value(row, mappings, :email),
          phone: get_mapped_value(row, mappings, :contact_phone),
          taxpayer_id: get_mapped_value(row, mappings, :taxpayer_id),
          active: parse_boolean(get_mapped_value(row, mappings, :active)),
          raw_data: row
        }.compact
      end

      # Get a value from a row using the configured field mapping
      def get_mapped_value(row, mappings, nodal_field)
        mapped_key = mappings[nodal_field]
        return nil if mapped_key.blank?

        # Try both the exact key and case-insensitive match
        row[mapped_key] || row[mapped_key.upcase] || row[mapped_key.downcase]
      end

      def parse_price(value)
        return nil if value.nil?

        numeric = case value
        when Numeric then value
        when String then value.to_f
        else return nil
        end

        (numeric * 100).round
      end

      def parse_integer(value)
        return nil if value.nil?

        value.to_i
      end

      def parse_boolean(value)
        return true if value.nil?
        return value if [true, false].include?(value)
        return true if value.to_s.downcase.in?(%w[true 1 yes active enabled act])

        false
      end

      # Field mappings from credentials
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

      # Field mappings from credentials
      def order_field_mappings
        mappings = credentials.dig(:field_mappings, :orders) ||
                   credentials.dig('field_mappings', 'orders') || {}
        mappings.transform_keys(&:to_sym)
      end

      def order_item_field_mappings
        mappings = credentials.dig(:field_mappings, :order_items) ||
                   credentials.dig('field_mappings', 'order_items') || {}
        mappings.transform_keys(&:to_sym)
      end

      # Safety: only allow valid Firebird identifiers
      def safe_table_name(name)
        sanitized = name.to_s.strip.upcase
        unless sanitized.match?(IDENTIFIER_PATTERN)
          raise Erp::ApiError, "Invalid table name: #{name}"
        end
        sanitized
      end

      def safe_column_name(name)
        sanitized = name.to_s.strip.upcase
        unless sanitized.match?(IDENTIFIER_PATTERN)
          raise Erp::ApiError, "Invalid column name: #{name}"
        end
        sanitized
      end

      # Normalize a Firebird row hash — convert encoding and stringify keys
      def normalize_row(row)
        normalized = {}
        row.each do |key, value|
          normalized[key.to_s] = convert_encoding(value)
        end
        normalized
      end

      # Convert values from Firebird encoding to UTF-8
      def convert_encoding(value)
        return value unless value.is_a?(String)

        value.encode('UTF-8', ruby_encoding, invalid: :replace, undef: :replace, replace: '?')
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        value.force_encoding('UTF-8')
      end

      # Encode values for writing to Firebird
      def encode_values(values)
        values.map do |value|
          next value unless value.is_a?(String)
          value.encode(ruby_encoding, 'UTF-8', invalid: :replace, undef: :replace, replace: '?')
        rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
          value
        end
      end

      # Extract field names and sample values from a row
      def extract_field_info(row)
        row.map do |key, value|
          converted = convert_encoding(value)
          {
            key: key.to_s,
            value: truncate_value(converted),
            type: value_type(converted)
          }
        end
      end

      def truncate_value(value)
        str = value.to_s
        str.length > 50 ? "#{str[0..47]}..." : str
      end

      def value_type(value)
        case value
        when Integer then 'integer'
        when Float, BigDecimal then 'float'
        when TrueClass, FalseClass then 'boolean'
        when Date, Time, DateTime then 'datetime'
        when NilClass then 'null'
        else 'string'
        end
      end

      # Map Firebird errors to friendly messages
      def friendly_error(error)
        message = error.message.to_s

        if message.include?('Unable to complete network request')
          "Could not connect to Firebird server at #{credentials[:host]}:#{credentials[:port] || 3050}"
        elsif message.include?('unavailable database')
          "Database not found: #{credentials[:database_path]}"
        elsif message.include?('Your user name and password are not defined')
          "Invalid username or password"
        elsif message.include?('Table unknown')
          table_match = message.match(/Table unknown\s+(\S+)/i)
          "Table not found: #{table_match ? table_match[1] : 'unknown'}"
        elsif message.include?('Column unknown')
          col_match = message.match(/Column unknown\s+(\S+)/i)
          "Column not found: #{col_match ? col_match[1] : 'unknown'}"
        elsif message.include?('lock conflict')
          "Database lock conflict — another process may be using the database"
        else
          "Firebird error: #{message.truncate(200)}"
        end
      end

      def raise_erp_error(error)
        friendly = friendly_error(error)

        if friendly.start_with?('Could not connect') || friendly.include?('not found:')
          raise Erp::ConnectionError, friendly
        else
          raise Erp::ApiError, friendly
        end
      end
    end
  end
end
