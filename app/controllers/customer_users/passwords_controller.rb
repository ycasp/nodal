class CustomerUsers::PasswordsController < Devise::PasswordsController
  before_action :set_organisation

  def after_resetting_password_path_for(_resource)
    home_path(org_slug: @organisation.slug)
  end

  # Override Devise's default which calls `new_session_path(:customer_user)`.
  # That route through `Devise::Controllers::UrlHelpers` resolves the helper
  # via `main_app`, a context that does NOT include our HostAwareUrlHelpers
  # dispatcher — so it picks the canonical slug-based route and raises
  # UrlGenerationError on a custom host where :org_slug isn't in params.
  # Calling the helper directly here lets the dispatcher swap to the
  # slug-less variant when appropriate.
  def after_sending_reset_password_instructions_path_for(_resource_name)
    new_customer_user_session_path(org_slug: @organisation.slug)
  end

  private

  # current_organisation resolves by request.host first (custom domain) and
  # falls back to params[:org_slug] so the reset flow works on either shape.
  def set_organisation
    @organisation = current_organisation || raise(ActiveRecord::RecordNotFound)
  end
end
