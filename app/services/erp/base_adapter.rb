module Erp
  class BaseAdapter
    attr_reader :credentials

    def initialize(credentials)
      @credentials = credentials.with_indifferent_access
    end

    def valid_credentials?
      raise NotImplementedError, "#{self.class} must implement #valid_credentials?"
    end

    def test_connection
      raise NotImplementedError, "#{self.class} must implement #test_connection"
    end

    def fetch_products
      raise NotImplementedError, "#{self.class} must implement #fetch_products"
    end

    def fetch_customers
      raise NotImplementedError, "#{self.class} must implement #fetch_customers"
    end

    def adapter_name
      self.class.name.demodulize.underscore.gsub('_adapter', '')
    end

    protected

    def http_client
      @http_client ||= build_http_client
    end

    def build_http_client
      Faraday.new do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.response :raise_error
        conn.adapter Faraday.default_adapter
        conn.options.timeout = 30
        conn.options.open_timeout = 10
      end
    end

    def handle_request_error(error)
      case error
      when Faraday::ConnectionFailed
        raise ConnectionError, "Could not connect to ERP: #{error.message}"
      when Faraday::TimeoutError
        raise ConnectionError, "Connection to ERP timed out"
      when Faraday::ClientError
        raise ApiError.from_response(error.response)
      else
        raise ApiError, "Unexpected error: #{error.message}"
      end
    end
  end
end
