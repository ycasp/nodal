class Members::SessionsController < Devise::SessionsController
  protected

  def after_sign_in_path_for(resource)
      bo_path(org_slug: current_organisation.slug)  # or whatever storefront path you want
  end
end
