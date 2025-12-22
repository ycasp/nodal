module ApplicationHelper
  # Returns the OrgMember record for current_member in current_organisation
  def current_org_member
    return nil unless defined?(current_member) && current_member
    return nil unless defined?(current_organisation) && current_organisation

    @current_org_member ||= OrgMember.find_by(
      member: current_member,
      organisation: current_organisation
    )
  end

  # Check if current member has admin or owner role
  def admin_or_owner?
    current_org_member&.role.in?(%w[admin owner])
  end

  # Check if current member is owner
  def owner?
    current_org_member&.role == 'owner'
  end
end
