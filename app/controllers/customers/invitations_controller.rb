class Customers::InvitationsController < Devise::InvitationsController
  before_action :set_organisation

  # After accepting invitation, redirect to sign in (don't auto sign-in)
  def after_accept_path_for(_resource)
    new_customer_session_path(org_slug: @organisation.slug)
  end

  protected

  def set_organisation
    @organisation = Organisation.find_by!(slug: params[:org_slug])
  end

  # Don't auto sign-in after accepting invitation
  # (scoped auth makes this problematic)
  def sign_in_and_redirect(_resource_or_scope, *_args)
    flash[:notice] = I18n.t("devise.invitations.updated")
    redirect_to after_accept_path_for(resource)
  end
end
