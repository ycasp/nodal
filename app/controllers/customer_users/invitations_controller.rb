class CustomerUsers::InvitationsController < Devise::InvitationsController
  before_action :set_organisation

  def after_accept_path_for(_resource)
    new_customer_user_session_path(org_slug: @organisation.slug)
  end

  protected

  # current_organisation resolves by request.host first (custom domain) and
  # falls back to params[:org_slug] so an invitation email link works on
  # whichever host the email was generated for.
  def set_organisation
    @organisation = current_organisation || raise(ActiveRecord::RecordNotFound)
  end

  # Don't auto sign-in after accepting invitation (scoped auth makes this problematic)
  def sign_in_and_redirect(_resource_or_scope, *_args)
    flash[:notice] = I18n.t("devise.invitations.updated")
    redirect_to after_accept_path_for(resource)
  end
end
