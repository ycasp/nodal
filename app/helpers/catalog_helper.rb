module CatalogHelper
  # Renders a scannable Code128 barcode of the given value as inline SVG for the
  # catalog PDF. The value is the variant SKU (the org-unique key the scan-to-cart
  # flow resolves against). Returns nil when the value is blank or barby can't
  # encode it, so one odd SKU never breaks the whole PDF render.
  def catalog_barcode_svg(value)
    value = value.to_s.strip
    return nil if value.blank?

    require "barby"
    require "barby/barcode/code_128"
    require "barby/outputter/svg_outputter"

    barcode = Barby::Code128B.new(value)
    svg = barcode.to_svg(height: 28, margin: 0, xdim: 1, show_text: false)
    svg.html_safe
  rescue StandardError => e
    Rails.logger.warn("[CatalogHelper] barcode render failed for #{value.inspect}: #{e.class}: #{e.message}")
    nil
  end
end
