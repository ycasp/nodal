class ShoppingListPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    customer_owner?
  end

  def create?
    user.is_a?(Customer)
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
      if user.is_a?(Customer)
        scope.where(customer: user)
      else
        scope.none
      end
    end
  end

  private

  def customer_owner?
    user.is_a?(Customer) && record.customer == user
  end
end
