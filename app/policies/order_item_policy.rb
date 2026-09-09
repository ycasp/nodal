class OrderItemPolicy < ApplicationPolicy
  def create?
    order_owner_and_draft? || member_impersonating_order_customer?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.is_a?(CustomerUser)
        scope.joins(:order).where(orders: { customer_user_id: user.id })
      elsif user.is_a?(Member)
        scope.joins(order: :organisation).where(organisations: { id: user.organisation_ids })
      else
        scope.none
      end
    end
  end

  private

  def order_owner_and_draft?
    user.is_a?(CustomerUser) &&
      record.order.customer_user_id == user.id &&
      record.order.draft?
  end

  # Sales reps act as the empresa during impersonation; they're allowed to
  # manage line items on the draft cart of the empresa they're impersonating.
  def member_impersonating_order_customer?
    return false unless user.is_a?(Member)
    return false unless context.is_a?(PunditContext) && context.impersonating?

    context.impersonated_customer_id.to_i == record.order.customer_id && record.order.draft?
  end
end
