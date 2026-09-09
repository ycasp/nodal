class OrderItemPolicy < ApplicationPolicy
  def create?
    order_owner_and_draft?
  end

  def update?
    order_owner_and_draft?
  end

  def destroy?
    order_owner_and_draft?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.is_a?(Customer)
        scope.joins(:order).where(orders: { customer_id: user.id })
      elsif user.is_a?(Member)
        scope.joins(order: :organisation).where(organisations: { id: user.organisation_ids })
      else
        scope.none
      end
    end
  end

  private

  def order_owner_and_draft?
    user.is_a?(Customer) &&
      record.order.customer == user &&
      record.order.draft?
  end
end
