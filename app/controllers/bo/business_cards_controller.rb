# frozen_string_literal: true

class Bo::BusinessCardsController < Bo::BaseController
  LAYOUTS = %w[card a4].freeze

  # GET /:org_slug/bo/business_card?layout=card|a4
  # Renders a generic, customer-agnostic business card whose QR points at
  # the storefront sign-in page. Meant to be printed and handed out.
  def show
    authorize current_organisation, :update?, policy_class: SettingPolicy

    layout = LAYOUTS.include?(params[:layout]) ? params[:layout] : "card"
    pdf = BusinessCardPdfRenderer.new(organisation: current_organisation, layout: layout).render_pdf

    filename = "#{current_organisation.slug}-cartao-#{layout}.pdf"
    send_data pdf, filename: filename, type: "application/pdf", disposition: "attachment"
  end
end
