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
      if user.is_a?(Customer)
        scope.joins(:shopping_list).where(shopping_lists: { customer_id: user.id })
      else
        scope.none
      end
    end
  end

  private

  def list_owner?
    user.is_a?(Customer) && record.shopping_list.customer == user
  end
end
