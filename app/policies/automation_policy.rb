# Deliberately stricter than the other settings tabs (SettingPolicy allows
# admin/owner too, but this one has no member-level fallback anywhere):
# creating an automation configures recurring delivery of business data to
# addresses outside the company. That is not a plain member's call.
class AutomationPolicy < ApplicationPolicy
  def index?   = admin_or_owner?
  def show?    = admin_or_owner?
  def create?  = admin_or_owner?
  def new?     = create?
  def update?  = admin_or_owner?
  def edit?    = update?
  def destroy? = admin_or_owner?
  def run_now? = admin_or_owner?
  def toggle?  = update?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if pure_sales_rep?

      member_working_for_organisation? ? scope.where(organisation: @organisation) : scope.none
    end
  end

  private

  def admin_or_owner?
    return false unless user.is_a?(Member)
    return false if pure_sales_rep?
    return false if @organisation.blank?

    OrgMember.find_by(member: user, organisation: @organisation)&.role.in?(%w[admin owner])
  end
end
