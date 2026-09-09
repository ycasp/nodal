# frozen_string_literal: true

# ActionText 7.1.x calls fragment.css("action-text-attachment") on every
# rich text read (canonicalization + to_trix_html). Nokogiri's HTML5
# visitor converts that CSS to the XPath
#   .//*:action-text-attachment | self::*:action-text-attachment
# using namespace-aware syntax. The libxml2 build shipped on Heroku-24
# rejects the `*:tag-name` form with "Invalid expression", so every
# product page that read rich_description was 500'ing.
#
# This patch routes the same lookups through Nokogiri::CSS.xpath_for
# with the default (non-namespaced) visitor and rewrites the leading
# `//` into a fragment-relative `.//`. Match semantics are identical and
# the resulting XPath is plain — accepted by every libxml2 version.
#
# Remove this initializer once we move past actiontext 7.1.x or the
# upstream gem stops emitting CSS selectors with that visitor.

require "action_text/fragment"

module ActionText
  class Fragment
    def find_all(selector)
      source.xpath(*compatible_xpath_for(selector))
    end

    def replace(selector)
      update do |source|
        source.xpath(*compatible_xpath_for(selector)).each do |node|
          replacement_node = yield(node)
          node.replace(replacement_node.to_s) if node != replacement_node
        end
      end
    end

    private

    def compatible_xpath_for(selector)
      Nokogiri::CSS.xpath_for(selector).map { |xp| xp.sub(/\A\/\//, ".//") }
    end
  end
end
