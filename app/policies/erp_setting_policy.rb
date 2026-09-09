class ErpSettingPolicy < ApplicationPolicy
  def edit?
    admin_or_owner?
  end

  def update?
    admin_or_owner?
  end

  def test_connection?
    admin_or_owner?
  end

  def fetch_sample?
    admin_or_owner?
  end

  def sync_now?
    admin_or_owner?
  end

  def sync_logs?
    admin_or_owner?
  end

  private

  def admin_or_owner?
    return false unless user.is_a?(Member)

    organisation = record.respond_to?(:organisation) ? record.organisation : record
    org_member = OrgMember.find_by(member: user, organisation: organisation)
    org_member&.role.in?(%w[admin owner])
  end
end
