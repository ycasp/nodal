class Members::SessionsController < Devise::SessionsController
  def create
    # Let Devise authenticate first
    self.resource = warden.authenticate!(auth_options)

    # Check if member belongs to current organisation
    unless resource.organisations.exists?(current_organisation&.id)
      sign_out(resource)
      set_flash_message!(:alert, :not_member_of_organisation)
      redirect_to new_member_session_path(org_slug: params[:org_slug])
      return
    end

    # Standard Devise flow continues
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end

  protected

  def after_sign_in_path_for(resource)
    bo_path(org_slug: current_organisation.slug)
  end
end
