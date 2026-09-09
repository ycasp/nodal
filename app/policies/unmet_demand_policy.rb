class UnmetDemandPolicy < ApplicationPolicy
  def index?
    bo_member?
  end

  def satisfy?
    bo_member?
  end

  def substitute?
    bo_member?
  end

  def dismiss?
    bo_member?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Decision 3: sales reps are out of this feature for v1.
      return scope.none if pure_sales_rep?

      member_working_for_organisation? ? scope.where(organisation: @organisation) : scope.none
    end
  end

  private

  # Org members, but not pure sales reps (decision 3).
  def bo_member?
    return false if pure_sales_rep?

    user.is_a?(Member) && @organisation.present? && user.organisations.include?(@organisation)
  end
end
