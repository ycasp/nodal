class CustomerUserPolicy < ApplicationPolicy
  def index?
    member_working_for_organisation?
  end

  def new?
    member_working_for_organisation?
  end

  def create?
    return false unless member_working_for_organisation?
    return true unless pure_sales_rep?
    # Pure rep: invite CustomerUser only for assigned customers
    customer_in_carteira?(record.customer)
  end

  def edit?
    return false unless record_belongs_to_user_organisation?
    return true unless pure_sales_rep?
    customer_in_carteira?(record.customer)
  end

  def update?
    edit?
  end

  def toggle_active?
    return false unless record_belongs_to_user_organisation?
    return true unless pure_sales_rep?
    customer_in_carteira?(record.customer)
  end

  # Resending an invitation only makes sense before the user accepts it.
  def resend_invitation?
    return false unless record_belongs_to_user_organisation? && record.invitation_status != :active
    return true unless pure_sales_rep?
    customer_in_carteira?(record.customer)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user_is_a_member?
        scope.where(organisation: @organisation)
      else
        scope.none
      end
    end
  end

  private

  # CustomerUser exposes organisation directly via belongs_to.
  def record_belongs_to_user_organisation?
    user_is_a_member? && @user.organisations.include?(record.organisation)
  end
end
