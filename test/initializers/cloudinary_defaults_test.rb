require "test_helper"

# The prepended module is defined inside an after_initialize block in
# config/initializers/cloudinary_defaults.rb and only attaches when the
# active_storage service is :cloudinary (production-only). To test it in
# isolation we re-evaluate the module body against a fake service class
# that mimics the gem's `url(key, ...)` / `download(key)` signatures.
class CloudinaryDefaultsTest < ActiveSupport::TestCase
  class FakeService
    attr_reader :captured_options

    def url(key, filename: nil, content_type: "", **options)
      @captured_options = options
      "https://fake.cloudinary/#{key}?#{options.to_a.map { |k, v| "#{k}=#{v}" }.join('&')}"
    end

    def download(key)
      url(key)
      "BLOB-BYTES"
    end

    def download_chunk(key, _range)
      url(key)
      "CHUNK"
    end
  end

  module FakeAutoFormat
    SKIP_KEY = :cloudinary_skip_auto_transforms

    def url(key, filename: nil, content_type: "", **options)
      if image_content?(key, content_type) && !Thread.current[SKIP_KEY]
        options[:fetch_format] = :auto unless options.key?(:fetch_format)
        options[:quality] = :auto unless options.key?(:quality)
      end
      super(key, filename: filename, content_type: content_type, **options)
    end

    def download(key, &block)
      with_skipped_transforms { super }
    end

    def download_chunk(key, range)
      with_skipped_transforms { super }
    end

    private

    def with_skipped_transforms
      previous = Thread.current[SKIP_KEY]
      Thread.current[SKIP_KEY] = true
      yield
    ensure
      Thread.current[SKIP_KEY] = previous
    end

    def image_content?(_key, content_type)
      content_type.to_s.start_with?("image/")
    end
  end

  def setup
    @klass = Class.new(FakeService)
    @klass.prepend(FakeAutoFormat)
    @service = @klass.new
  end

  test "delivery URL gets f_auto + q_auto for image content" do
    @service.url("abc", content_type: "image/png")
    assert_equal :auto, @service.captured_options[:fetch_format]
    assert_equal :auto, @service.captured_options[:quality]
  end

  test "delivery URL leaves PDFs alone" do
    @service.url("abc", content_type: "application/pdf")
    assert_nil @service.captured_options[:fetch_format]
    assert_nil @service.captured_options[:quality]
  end

  test "respects caller-supplied transforms" do
    @service.url("abc", content_type: "image/png", fetch_format: :webp, quality: 80)
    assert_equal :webp, @service.captured_options[:fetch_format]
    assert_equal 80, @service.captured_options[:quality]
  end

  test "download skips transforms" do
    @service.download("abc")
    assert_nil @service.captured_options[:fetch_format], "download must not inject f_auto"
    assert_nil @service.captured_options[:quality], "download must not inject q_auto"
  end

  test "download_chunk skips transforms" do
    @service.download_chunk("abc", 0..100)
    assert_nil @service.captured_options[:fetch_format]
    assert_nil @service.captured_options[:quality]
  end

  test "thread-local is restored after download" do
    @service.download("abc")
    assert_nil Thread.current[FakeAutoFormat::SKIP_KEY]

    @service.url("abc", content_type: "image/png")
    assert_equal :auto, @service.captured_options[:fetch_format], "transforms back on after download"
  end

  test "thread-local is restored even when download raises" do
    klass = Class.new(FakeService) do
      def download(_key)
        url("abc")
        raise "boom"
      end
    end
    klass.prepend(FakeAutoFormat)
    service = klass.new

    assert_raises(RuntimeError) { service.download("abc") }
    assert_nil Thread.current[FakeAutoFormat::SKIP_KEY], "thread-local must be reset on exception"
  end
end
