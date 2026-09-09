class ShoppingListPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    customer_owner?
  end

  def create?
    user.is_a?(CustomerUser)
  end

  def update?
    customer_owner?
  end

  def destroy?
    customer_owner?
  end

  def add_to_cart?
    customer_owner?
  end

  def product_picker?
    customer_owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.is_a?(CustomerUser)
        scope.where(customer_id: user.customer_id)
      else
        scope.none
      end
    end
  end

  private

  def customer_owner?
    user.is_a?(CustomerUser) && record.customer_id == user.customer_id
  end
end
