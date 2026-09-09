require_relative "boot"

require "rails/all"
require_relative "../app/middleware/block_bot_user_agents"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Nodal
  class Application < Rails::Application
    config.action_controller.raise_on_missing_callback_actions = false if Rails.version >= "7.1.0"
    config.generators do |generate|
      generate.assets false
      generate.helper false
      generate.test_framework :test_unit, fixture: false
    end

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Internationalization
    config.i18n.available_locales = [:en, :pt, :es]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = true
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]

    # Use Solid Queue for background jobs (PostgreSQL-backed, no Redis needed)
    config.active_job.queue_adapter = :solid_queue

    config.middleware.insert_before Rack::Runtime, BlockBotUserAgents

    # Host used to serve the BO and as the always-on fallback for storefront.
    # Custom-domain requests redirect BO traffic here. Override via env var
    # for dev/test or alternative deployments.
    config.x.canonical_host = ENV.fetch("CANONICAL_HOST", "nodal-seiri.dev")

    # Domain used in the "no-reply@…" From: header of outgoing emails. By
    # default we strip a leading "www." from canonical_host so the sender
    # lives on the apex that Resend authorises; override here when the
    # convention doesn't fit (e.g. mail.example.com).
    config.x.mail_sender_domain = ENV.fetch("MAIL_SENDER_DOMAIN", nil)
  end
end
