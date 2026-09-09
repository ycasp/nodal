class CustomerPolicy < ApplicationPolicy
  def export?
    return false unless member_working_for_organisation?
    # Pure reps can't dump the full customer list — sensitive across carteiras.
    !pure_sales_rep?
  end

  def show?
    # All org members may view any customer. Pure reps see only basic info
    # for customers outside their carteira (UI-level filtering, not policy).
    member_working_for_organisation? && record_belongs_to_user_organisation?
  end

  def update?
    return false unless member_working_for_organisation? && record_belongs_to_user_organisation?
    return true unless pure_sales_rep?

    customer_in_carteira?(record)
  end

  def destroy?
    return false if pure_sales_rep?

    member_working_for_organisation? && record_belongs_to_user_organisation?
  end

  def new?
    # All members can create. Sales reps create through a guarded form with
    # locked fields (Section 3); admins/owners through the full form.
    member_working_for_organisation?
  end

  def create?
    new?
  end

  def invite?
    return false unless member_working_for_organisation? && record_belongs_to_user_organisation?
    return true unless pure_sales_rep?

    customer_in_carteira?(record)
  end

  # Manage logins modal — same gate as invite (creating/editing logins is
  # the rep's path to onboarding customers in their carteira).
  def logins_modal?
    invite?
  end

  class Scope < ApplicationPolicy::Scope
    # NOTE: Be explicit about which records you allow access to!
    def resolve
      raise Pundit::NotAuthorizedError unless member_working_for_organisation?

      # All members (including pure reps) see all org customers in lists —
      # the carteira view is a separate filtered query, not a scope restriction.
      # Vacation-coverage read-only is enforced at action level (show/update).
      scope.where(organisation: @organisation)
    end
  end
end
