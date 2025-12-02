class Bo::BaseController < ApplicationController
  before_action :check_membership

  private

  # done before every bo/ route - checks if member is part of current org
  # redirets to root if not
  def check_membership
    return if !current_member.nil? && current_member.organisations.exists?(current_organisation.id)
    flash[:alert]
    redirect_to(root_path)
  end
end
