# frozen_string_literal: true

# Pagy configuration
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Default items per page
Pagy::DEFAULT[:limit] = 24

# Use Bootstrap 5 styling
require 'pagy/extras/bootstrap'

# Enable overflow handling (e.g., when page > last_page)
require 'pagy/extras/overflow'
Pagy::DEFAULT[:overflow] = :last_page
