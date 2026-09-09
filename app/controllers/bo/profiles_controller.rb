class Bo::ProfilesController < Bo::BaseController
  def edit
    org_member = current_organisation.org_members.find_by!(member: current_member)
    redirect_to edit_bo_team_member_path(params[:org_slug], org_member)
  end

  def update
    org_member = current_organisation.org_members.find_by!(member: current_member)
    redirect_to edit_bo_team_member_path(params[:org_slug], org_member)
  end
end
