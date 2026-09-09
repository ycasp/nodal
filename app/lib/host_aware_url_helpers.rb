# Makes URL generation respect the host the request is being served from.
#
# Rails route definitions in config/routes/storefront.rb are drawn twice
# (slug-based and slug-less-on-custom-host). Each produces a separate set of
# helpers: products_path (slug-based, canonical) and custom_host_products_path
# (slug-less). Views and controllers everywhere use the canonical name; this
# module overrides them so that on a custom host the canonical call returns
# the slug-less URL instead.
#
# The actual method definitions are installed by Dispatcher.install! once the
# route table is loaded (via to_prepare in
# config/initializers/install_host_aware_url_helpers.rb), and re-installed in
# dev whenever routes reload.
module HostAwareUrlHelpers
  extend ActiveSupport::Concern

  # True when this request is served from an organisation's custom_domain
  # rather than the canonical host. Memoised per-request. Returns false in
  # contexts without a request (mailers, jobs) where the predicate is
  # meaningless — those callers should resolve URLs explicitly via the
  # target organisation's preferred host.
  def on_custom_host?
    return @on_custom_host if defined?(@on_custom_host)

    @on_custom_host =
      begin
        request.present? && CustomDomainConstraint.new.matches?(request)
      rescue StandardError
        false
      end
  end

  module Dispatcher
    class << self
      # Rails 7.1's named_routes.helper_names returns the full method names
      # (e.g. "products_path", "new_custom_host_customer_user_session_path"),
      # so we match on the literal "custom_host_" segment wherever it appears.
      CUSTOM_HOST_TAG = "custom_host_"

      def install!
        helpers = Rails.application.routes.named_routes.helper_names.map(&:to_s)
        custom_helpers = helpers.select { |h| h.include?(CUSTOM_HOST_TAG) }

        installed = []
        custom_helpers.each do |custom_helper|
          base_helper = custom_helper.sub(CUSTOM_HOST_TAG, "")
          next unless helpers.include?(base_helper)
          next if installed.include?(base_helper)

          HostAwareUrlHelpers.module_eval <<~RUBY, __FILE__, __LINE__ + 1
            def #{base_helper}(*args, **opts)
              if on_custom_host?
                opts.delete(:org_slug)
                #{custom_helper}(*args, **opts)
              else
                super
              end
            end
          RUBY
          installed << base_helper
        end

        installed
      end
    end
  end
end
