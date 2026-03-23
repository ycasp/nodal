class Storefront::LegalPagesController < Storefront::BaseController
  skip_before_action :authenticate_customer!
  skip_after_action :verify_authorized

  def terms
    @content = current_organisation.terms_and_conditions
    if @content.blank?
      redirect_to products_path(org_slug: current_organisation.slug), notice: t("storefront.legal_pages.no_content")
      return
    end
  end

  def privacy
    @content = current_organisation.privacy_policy
    if @content.blank?
      redirect_to products_path(org_slug: current_organisation.slug), notice: t("storefront.legal_pages.no_content")
      return
    end
  end
end
