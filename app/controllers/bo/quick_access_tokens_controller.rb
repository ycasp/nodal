class Bo::QuickAccessTokensController < Bo::BaseController
  before_action :set_customer
  before_action :set_customer_user
  before_action :load_token, only: [:show, :destroy, :download]

  FORMATS = %w[card digital].freeze

  def show
    authorize @customer_user, :edit?, policy_class: CustomerUserPolicy
    # rqrcode is gem'd as require:false to keep boot light; the view
    # renders an inline QR SVG via RQRCode::QRCode, so load it here.
    require "rqrcode"
  end

  def create
    authorize @customer_user, :edit?, policy_class: CustomerUserPolicy

    unless @customer_user.invitation_status == :active
      redirect_to bo_customer_customer_user_quick_access_token_path(
                    org_slug: params[:org_slug],
                    customer_id: @customer.id,
                    customer_user_id: @customer_user.id
                  ),
                  alert: t("bo.quick_access_tokens.flash.user_not_ready") and return
    end

    @token = QuickAccessToken.generate_for(@customer_user, created_by: current_member)
    redirect_to bo_customer_customer_user_quick_access_token_path(
                  org_slug: params[:org_slug],
                  customer_id: @customer.id,
                  customer_user_id: @customer_user.id
                ),
                notice: t("bo.quick_access_tokens.flash.generated")
  end

  def destroy
    authorize @customer_user, :edit?, policy_class: CustomerUserPolicy
    @token&.revoke!
    redirect_to bo_customer_path(params[:org_slug], @customer),
                notice: t("bo.quick_access_tokens.flash.revoked")
  end

  def download
    authorize @customer_user, :edit?, policy_class: CustomerUserPolicy

    unless @token&.active?
      redirect_to bo_customer_path(params[:org_slug], @customer),
                  alert: t("bo.quick_access_tokens.flash.not_active") and return
    end

    fmt = FORMATS.include?(params[:layout]) ? params[:layout] : "card"
    attachment = @token.attached_pdf(fmt)

    unless attachment.attached?
      redirect_to bo_customer_customer_user_quick_access_token_path(
                    org_slug: params[:org_slug],
                    customer_id: @customer.id,
                    customer_user_id: @customer_user.id
                  ),
                  alert: t("bo.quick_access_tokens.flash.still_generating") and return
    end

    # rails_storage_proxy serves the bytes through Rails so we control
    # the Content-Disposition header. Cloudinary signed URLs ignore the
    # disposition param ActiveStorage tries to pass through, so a direct
    # redirect would open the PDF inline in the browser instead of
    # downloading it. The bandwidth cost is trivial for the rare merchant
    # click and the UX is predictable.
    redirect_to rails_storage_proxy_path(attachment, disposition: "attachment")
  end

  private

  def set_customer
    @customer = current_organisation.customers.find(params[:customer_id])
  end

  def set_customer_user
    @customer_user = @customer.customer_users.find(params[:customer_user_id])
  end

  def load_token
    @token = @customer_user.quick_access_tokens.active.first
  end
end
