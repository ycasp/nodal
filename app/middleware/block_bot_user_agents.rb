class BlockBotUserAgents
  BLOCKED_PATTERNS = [
    /\ARuby(\z|\/)/,
    /\APython-urllib/,
    /\Apython-requests/,
    /\Acurl\//,
    /\AWget\//,
    /\Ago-http-client/,
    /\AJava\//,
    /\Aaiohttp\//
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    user_agent = env["HTTP_USER_AGENT"].to_s
    if BLOCKED_PATTERNS.any? { |pattern| user_agent.match?(pattern) }
      return [403, { "Content-Type" => "text/plain", "Cache-Control" => "no-store" }, ["Forbidden"]]
    end
    @app.call(env)
  end
end
