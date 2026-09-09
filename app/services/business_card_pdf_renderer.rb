class BusinessCardPdfRenderer
  include Rails.application.routes.url_helpers
  include HostAwareUrlHelpers

  PdfFormatError = Class.new(StandardError)

  GROVER_OPTIONS = {
    card: { format: nil, width: "85mm",  height: "55mm",  margin: { top: "0", bottom: "0", left: "0", right: "0" }, prefer_css_page_size: true }.freeze,
    a4:   { format: "A4",                                   margin: { top: "0", bottom: "0", left: "0", right: "0" }, prefer_css_page_size: true }.freeze
  }.freeze

  def initialize(organisation:, layout:)
    @organisation = organisation
    @layout = layout.to_sym
    raise PdfFormatError, "unknown layout #{layout}" unless GROVER_OPTIONS.key?(@layout)
  end

  def render_pdf
    Grover.new(html, **GROVER_OPTIONS.fetch(@layout)).to_pdf
  end

  # Background context — HostAwareUrlHelpers' dispatcher uses this to pick
  # between slug-based and slug-less variants of the sign-in URL.
  def on_custom_host?
    @organisation&.custom_domain_verified?
  end

  def default_url_options
    if Rails.env.production?
      { host: @organisation&.preferred_host || Rails.application.config.x.canonical_host, protocol: "https" }
    else
      { host: "localhost", port: 3000, protocol: "http" }
    end
  end

  private

  def html
    url = new_customer_user_session_url(org_slug: @organisation.slug)

    ApplicationController.render(
      template: "bo/business_cards/pdf_#{@layout}",
      layout: false,
      assigns: {
        organisation: @organisation,
        sign_in_url: url,
        qr_svg: build_qr_svg(url)
      }
    )
  end

  def build_qr_svg(data)
    require "rqrcode"
    qr = RQRCode::QRCode.new(data, level: :m)
    qr.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true,
      viewbox: true
    )
  end
end
