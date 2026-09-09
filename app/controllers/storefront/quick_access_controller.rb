class Storefront::QuickAccessController < ApplicationController
  # Public landing — no authentication required. Validates the token,
  # records a qr_landing audit event, then redirects to the customer
  # sign-in page with the email pre-filled and a from_qr session flag.
  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    token = QuickAccessToken.active.find_by(token: params[:token])

    if token && token.customer_user.organisation == current_organisation
      cu = token.customer_user
      token.mark_used!
      log_landing(cu, success: true)
      session[:from_qr] = true
      redirect_to new_customer_user_session_path(
        org_slug: current_organisation.slug,
        customer_user: { email: cu.email }
      )
    else
      log_landing(nil, success: false, reason: "invalid_or_expired_token")
      redirect_to new_customer_user_session_path(org_slug: current_organisation.slug),
                  alert: t("storefront.quick_access.invalid")
    end
  end

  private

  def log_landing(customer_user, success:, reason: nil)
    return unless current_organisation

    CustomerUserLoginEvent.create!(
      customer_user: customer_user,
      organisation: current_organisation,
      method: "qr_landing",
      success: success,
      ip_address: request.remote_ip,
      user_agent: request.user_agent.to_s.first(255),
      failure_reason: reason
    )
  end
end
