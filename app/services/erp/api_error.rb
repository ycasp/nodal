module Erp
  class ApiError < StandardError
    attr_reader :response, :status_code

    def initialize(message, response: nil, status_code: nil)
      @response = response
      @status_code = status_code
      super(message)
    end

    def self.from_response(response)
      status_code = response[:status]
      body = response[:body]

      message = case status_code
      when 401
        "Authentication failed - check your API credentials"
      when 403
        "Access forbidden - insufficient permissions"
      when 404
        "Resource not found"
      when 429
        "Rate limit exceeded - too many requests"
      when 500..599
        "ERP server error (#{status_code})"
      else
        "API request failed with status #{status_code}"
      end

      new(message, response: body, status_code: status_code)
    end
  end
end
