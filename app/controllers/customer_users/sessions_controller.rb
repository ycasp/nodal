class CustomerUsers::SessionsController < Devise::SessionsController
  before_action :set_organisation
  before_action :configure_sign_in_params, only: :create

  def create
    customer_user = @organisation.customer_users.find_by(email: sign_in_params[:email])
    from_qr = session.delete(:from_qr).present?

    if customer_user&.valid_password?(sign_in_params[:password]) && customer_user.active_for_authentication?
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, customer_user)
      log_login_event(customer_user, from_qr: from_qr, success: true)
      yield customer_user if block_given?
      respond_with customer_user, location: after_sign_in_path_for(customer_user)
    else
      reason = if customer_user.nil?
                 "unknown_email"
               elsif !customer_user.valid_password?(sign_in_params[:password])
                 "wrong_password"
               else
                 customer_user.inactive_message.to_s
               end
      log_login_event(customer_user, from_qr: from_qr, success: false, reason: reason)
      self.resource = resource_class.new(sign_in_params)
      set_flash_message!(:alert, :invalid)
      render :new, status: :unprocessable_entity
    end
  end

  private

  # current_organisation resolves by request.host first (custom domain) and
  # falls back to params[:org_slug] (canonical slug URL), so sign-in works
  # whichever shape the form was submitted from.
  def set_organisation
    @organisation = current_organisation || raise(ActiveRecord::RecordNotFound)
  end

  # Inject organisation_id so Devise authenticates on [email, organisation_id]
  def configure_sign_in_params
    params[:customer_user] ||= {}
    params[:customer_user][:organisation_id] = @organisation.id
    devise_parameter_sanitizer.permit(:sign_in, keys: [:organisation_id])
  end

  def after_sign_in_path_for(resource)
    home_path(org_slug: current_organisation.slug)
  end

  def log_login_event(customer_user, from_qr:, success:, reason: nil)
    CustomerUserLoginEvent.create!(
      customer_user: customer_user,
      organisation: @organisation,
      method: from_qr ? "qr_password" : "password",
      success: success,
      ip_address: request.remote_ip,
      user_agent: request.user_agent.to_s.first(255),
      failure_reason: reason
    )
  rescue StandardError => e
    Rails.logger.warn("[CustomerUserLoginEvent] failed to log: #{e.message}")
  end
end
