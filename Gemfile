source "https://rubygems.org"

ruby "3.3.5"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.6"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

gem "bootstrap", "~> 5.3"
gem "autoprefixer-rails"
gem "font-awesome-sass", "~> 6.1"
gem "simple_form", github: "heartcombo/simple_form"
gem "sassc-rails"

# gem for authentification
gem "devise"
# gem for invitations - building on top of devise
gem 'devise_invitable', '~> 2.0.0'

# gem for picuture saving - heroku is empheral
gem "cloudinary"

# gem for using llm
gem "ruby_llm"

# gem for markdown rendering
gem "kramdown"
gem "rouge"
gem "kramdown-parser-gfm"

# gem for multi-modal processing
gem "image_processing", "~> 1.2"

# open uri
gem 'open-uri'

# gem for authorization
gem 'pundit'

# gem for hierarchical categories
gem 'ancestry'       # Tree structure
gem 'acts_as_list'   # Sibling ordering
gem 'discard'        # Soft delete

# gem for money handling
gem 'money-rails', '~> 1.12'

# pagination
gem 'pagy', '~> 9.0'

# background jobs
gem 'solid_queue', '~> 1.1'

# HTTP client for ERP integrations
gem 'faraday', '~> 2.0'

# ZIP file handling for product image import — only loaded by the
# image import service / rake task, kept out of the boot path.
gem 'rubyzip', '~> 2.3', require: false

# Excel file parsing for product import — only loaded by import jobs.
gem 'roo', '~> 2.10', require: false

# Excel file generation for exports — only loaded by ExportService.
gem 'caxlsx', '~> 4.1', require: false

# PDF generation from HTML (uses Chrome headless). Referenced at
# class-load time by GenerateQuickAccessPdfsJob#retry_on, so eager
# loading would pull it in anyway — keep it required at boot.
gem 'grover', '~> 1.1'

# QR code generation (used only by QuickAccessPdfRenderer).
gem 'rqrcode', '~> 2.2', require: false

# Code128 barcode generation for the catalog PDF (scan-to-cart). Rendered as
# inline SVG in the catalog templates; required lazily by CatalogHelper.
gem 'barby', '~> 0.7', require: false

# PDF merging for chunked catalog generation — only by CatalogPdfService.
gem 'combine_pdf', '~> 1.0', require: false

# Firebird database client for direct ERP connections
# Requires libfbclient native library (installed on Heroku via Aptfile)
# Install with: bundle config set --local with firebird && bundle install
group :firebird do
  gem 'fb', '~> 0.9', require: false
end

# Resend for mailing (via SMTP, no gem needed)

group :development, :test do
  gem "dotenv-rails"
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  # gems for debbubg
  gem "httplog"
  gem "pry-byebug"
  gem "pry-rails"

  gem "letter_opener_web"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
