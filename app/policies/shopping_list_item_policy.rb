class ShoppingListItemPolicy < ApplicationPolicy
  def create?
    list_owner?
  end

  def update?
    list_owner?
  end

  def destroy?
    list_owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.is_a?(CustomerUser)
        scope.joins(:shopping_list).where(shopping_lists: { customer_id: user.customer_id })
      else
        scope.none
      end
    end
  end

  private

  def list_owner?
    user.is_a?(CustomerUser) && record.shopping_list.customer_id == user.customer_id
  end
end
