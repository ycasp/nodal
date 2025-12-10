class SettingPolicy < ApplicationPolicy
  # Only admin or owner can edit organisation settings
  def edit?
    admin_or_owner?
  end

  def update?
    admin_or_owner?
  end

  private

  def admin_or_owner?
    return false unless user.is_a?(Member)

    org_member = OrgMember.find_by(member: user, organisation: record)
    org_member&.role.in?(%w[admin owner])
  end
end
