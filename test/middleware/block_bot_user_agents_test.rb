require "test_helper"

class BlockBotUserAgentsTest < ActiveSupport::TestCase
  def setup
    @app = ->(_env) { [200, {}, ["ok"]] }
    @middleware = BlockBotUserAgents.new(@app)
  end

  test "blocks default Ruby user agent" do
    status, _headers, body = @middleware.call("HTTP_USER_AGENT" => "Ruby")
    assert_equal 403, status
    assert_equal ["Forbidden"], body
  end

  test "blocks Ruby with version suffix" do
    status, = @middleware.call("HTTP_USER_AGENT" => "Ruby/3.3.5")
    assert_equal 403, status
  end

  test "blocks common bot user agents" do
    %w[
      Python-urllib/3.9
      python-requests/2.31.0
      curl/8.0.1
      Wget/1.21
      go-http-client/1.1
      Java/17.0
      aiohttp/3.8.5
    ].each do |ua|
      status, = @middleware.call("HTTP_USER_AGENT" => ua)
      assert_equal 403, status, "expected #{ua} to be blocked"
    end
  end

  test "allows real browsers" do
    %w[
      Mozilla/5.0
      Chrome/120.0
    ].each do |ua|
      status, = @middleware.call("HTTP_USER_AGENT" => ua)
      assert_equal 200, status, "expected #{ua} to pass"
    end
  end

  test "allows missing user agent" do
    status, = @middleware.call({})
    assert_equal 200, status
  end

  test "does not block strings that contain Ruby mid-token" do
    status, = @middleware.call("HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; Rubyworld)")
    assert_equal 200, status
  end
end
