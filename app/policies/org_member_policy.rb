class OrgMemberPolicy < ApplicationPolicy
  # All members can view team (record is the class OrgMember for index)
  def index?
    user.is_a?(Member)
  end

  # Admin/Owner can invite new members
  def new?
    admin_or_owner?
  end

  def create?
    admin_or_owner?
  end

  # Only owner can edit roles
  def edit?
    owner? && !editing_self?
  end

  def update?
    owner? && !editing_self?
  end

  # Owner can remove anyone except themselves
  def destroy?
    return false if editing_self?
    return true if owner?

    false
  end

  # Toggle active status
  def toggle_active?
    return false if editing_self?
    return true if owner?

    # Admins can toggle members but not other admins/owners
    admin? && record.role == 'member'
  end

  def resend_invitation?
    admin_or_owner? && record.pending_invitation?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  private

  def organisation
    @org ||= if record.is_a?(OrgMember)
               record.organisation
             else
               super
             end
  end

  def current_org_member
    return nil unless organisation

    @current_org_member ||= OrgMember.find_by(member: user, organisation: organisation)
  end

  def owner?
    current_org_member&.role == 'owner'
  end

  def admin?
    current_org_member&.role == 'admin'
  end

  def admin_or_owner?
    current_org_member&.role.in?(%w[admin owner])
  end

  def editing_self?
    record.is_a?(OrgMember) && record.member_id == user.id
  end
end
