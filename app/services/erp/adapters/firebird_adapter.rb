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
          query_as_hashes(db, build_select_sql(products_table, products_filter))
        end

        rows.map { |row| normalize_product(normalize_row(row)) }
      rescue => e
        raise_erp_error(e)
      end

      def fetch_customers
        return [] unless valid_credentials?

        rows = with_connection do |db|
          query_as_hashes(db, build_select_sql(customers_table, customers_filter))
        end

        rows.map { |row| normalize_customer(normalize_row(row)) }
      rescue => e
        raise_erp_error(e)
      end

      # Streams products one at a time through the cursor without materializing
      # the full result set. Keeps peak memory bounded regardless of table size.
      def each_product(&block)
        return enum_for(:each_product) unless block_given?
        return unless valid_credentials?

        with_connection do |db|
          each_row_as_hash(db, build_select_sql(products_table, products_filter)) do |row|
            yield normalize_product(normalize_row(row))
          end
        end
      rescue => e
        raise_erp_error(e)
      end

      def each_customer(&block)
        return enum_for(:each_customer) unless block_given?
        return unless valid_credentials?

        with_connection do |db|
          each_row_as_hash(db, build_select_sql(customers_table, customers_filter)) do |row|
            yield normalize_customer(normalize_row(row))
          end
        end
      rescue => e
        raise_erp_error(e)
      end

      # Returns the row count the given filter would select for the entity type.
      # When filter is nil, falls back to the configured filter for the entity.
      # Used by the UI to validate filters before running a sync.
      def count_rows(entity_type, filter = :unset)
        return 0 unless valid_credentials?

        table = case entity_type.to_s
                when 'products'  then products_table
                when 'customers' then customers_table
                else raise Erp::ApiError, "Unsupported entity_type: #{entity_type}"
                end

        effective_filter = if filter == :unset
                             entity_type.to_s == 'products' ? products_filter : customers_filter
                           else
                             filter.to_s.strip.presence
                           end

        sql = "SELECT COUNT(*) FROM #{safe_table_name(table)}"
        sql += " WHERE #{effective_filter}" if effective_filter

        with_connection do |db|
          row = db.execute(sql).fetch
          row && row[0].to_i
        end
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

      # Pushes an order to the ERP using the configured field mappings and static values.
      #
      # Supports flat-schema ERPs (one table for header+lines, repeated header data per
      # line row — e.g. PDA_PEDIDOS). The first line is inserted with the order_number
      # column set to 0 so the ERP's trigger/generator assigns the real number; the
      # assigned value is then captured via the idempotency key and reused for
      # subsequent lines.
      #
      # Idempotency: if an idempotency_key mapping is configured and a row with the
      # same key already exists, the insert is skipped and the existing external_id
      # is returned.
      def push_order(order_data)
        return { success: false, error: 'Missing credentials' } unless valid_credentials?

        order_data = order_data.with_indifferent_access
        mappings = order_field_mappings
        statics = order_static_values
        idempotency_col = mappings[:idempotency_key]
        idempotency_key = order_data[:idempotency_key]
        pedido_col = mappings[:order_number]
        linha_col = mappings[:line_number]

        items = Array(order_data[:items])
        return { success: false, error: 'Order has no items' } if items.empty?

        with_connection do |db|
          # Idempotency check
          if idempotency_col.present? && idempotency_key.present? && pedido_col.present?
            existing_pedido = find_existing_pedido(db, pedido_col, idempotency_col, idempotency_key)
            return { success: true, external_id: existing_pedido.to_s, idempotent: true } if existing_pedido
          end

          assigned_pedido = nil

          db.transaction do
            items.each_with_index do |item_data, index|
              line_data = build_line_row(
                order_data: order_data,
                item_data: item_data.with_indifferent_access,
                mappings: mappings,
                statics: statics,
                pedido_value: assigned_pedido || 0,
                pedido_col: pedido_col,
                linha_col: linha_col
              )

              cols = line_data.keys.map { |c| safe_column_name(c) }
              placeholders = cols.map { '?' }.join(', ')
              sql = "INSERT INTO #{safe_table_name(orders_table)} (#{cols.join(', ')}) VALUES (#{placeholders})"
              db.execute(sql, *encode_values(line_data.values))

              # After the first line, capture the PEDIDO the trigger assigned so
              # subsequent lines attach to the same order.
              if index.zero? && pedido_col.present? && idempotency_col.present? && idempotency_key.present?
                assigned_pedido = find_existing_pedido(db, pedido_col, idempotency_col, idempotency_key)
                raise Erp::ApiError, "Could not determine PEDIDO assigned by ERP after insert" if assigned_pedido.nil?
              end
            end
          end

          { success: true, external_id: assigned_pedido&.to_s }
        end
      rescue => e
        raise_erp_error(e)
      end

      private

      # SELECT the order_number column by idempotency key. Returns nil if not found.
      def find_existing_pedido(db, pedido_col, idempotency_col, idempotency_key)
        sql = "SELECT #{safe_column_name(pedido_col)} FROM #{safe_table_name(orders_table)} " \
              "WHERE #{safe_column_name(idempotency_col)} = ? " \
              "ORDER BY #{safe_column_name(pedido_col)} DESC"
        cursor = db.execute(sql, *encode_values([idempotency_key]))
        row = cursor.fetch
        row ? row[0] : nil
      ensure
        cursor&.close
      end

      # Builds a single row to insert: header fields (repeated on every line) +
      # per-line fields + static values + auto-assigned PEDIDO/PEDIDO_LINHA overrides.
      def build_line_row(order_data:, item_data:, mappings:, statics:, pedido_value:, pedido_col:, linha_col:)
        row = {}

        # Header-level Nodal concepts (same for every line of the same order)
        %i[customer_external_id delivery_date notes idempotency_key location_id].each do |nodal_key|
          erp_col = mappings[nodal_key]
          next if erp_col.blank?
          val = order_data[nodal_key]
          row[erp_col] = val unless val.nil?
        end

        # Per-line Nodal concepts
        %i[product_code quantity unit_price].each do |nodal_key|
          erp_col = mappings[nodal_key]
          next if erp_col.blank?
          val = item_data[nodal_key]
          row[erp_col] = val unless val.nil?
        end

        # Static values fill columns that don't come from order data. Don't override
        # anything already set (derived fields take priority).
        statics.each do |erp_col, val|
          next if erp_col.blank?
          row[erp_col] ||= val
        end

        # Auto-assigned: order_number and line_number go last so they always override
        row[pedido_col] = pedido_value if pedido_col.present?
        row[linha_col] = 0 if linha_col.present?

        row
      end

      # --- existing helpers below ---

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

      def build_select_sql(table, filter)
        sql = "SELECT * FROM #{safe_table_name(table)}"
        sql += " WHERE #{filter}" if filter.present?
        sql
      end

      # Streaming variant of query_as_hashes — yields each row as a hash without
      # accumulating all rows in memory.
      def each_row_as_hash(db, sql)
        cursor = db.execute(sql)
        columns = cursor.fields.map { |f| f.name.to_s }
        while (row = cursor.fetch)
          hash = {}
          columns.each_with_index { |col, i| hash[col] = row[i] }
          yield hash
        end
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

      def products_filter
        credentials[:products_filter].to_s.strip.presence
      end

      def customers_filter
        credentials[:customers_filter].to_s.strip.presence
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
          supplier: get_mapped_value(row, mappings, :supplier),
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
          billing_address: extract_address(row, mappings, :billing),
          shipping_address: extract_address(row, mappings, :shipping),
          raw_data: row
        }.compact
      end

      # Reads address fields for a given prefix (:billing or :shipping) from
      # the row using the configured mappings. Returns nil if all source
      # fields are blank — caller treats nil as "ERP did not provide this
      # address, do not sync".
      def extract_address(row, mappings, prefix)
        keys = %i[street_name street_nr postal_code city country]
        values = keys.each_with_object({}) do |key, acc|
          mapped = get_mapped_value(row, mappings, :"#{prefix}_#{key}")
          acc[key] = mapped.to_s.strip if mapped.present?
        end
        return nil if values.values.all?(&:blank?)
        values
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

      # Unified mapping of Nodal order concepts → ERP column name. Covers both
      # header-level concepts (customer_external_id, delivery_date, notes,
      # idempotency_key, location_id) and per-line concepts (product_code,
      # quantity, unit_price) plus auto-assigned ones (order_number, line_number).
      def order_field_mappings
        mappings = credentials.dig(:field_mappings, :orders) ||
                   credentials.dig('field_mappings', 'orders') || {}
        mappings.transform_keys(&:to_sym)
      end

      # ERP column → fixed value, for columns the Nodal order data doesn't
      # populate (UTILIZADOR, VENDEDOR, ARMAZEM, ESTADO, BCI, etc.).
      def order_static_values
        statics = credentials[:order_static_values] ||
                  credentials['order_static_values'] || {}
        statics.transform_keys(&:to_s)
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
