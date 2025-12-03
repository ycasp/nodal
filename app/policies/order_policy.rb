class OrderPolicy < ApplicationPolicy

  def show?
    true
  end

  def edit?
    true
  end

  def update?
    true
  end

  def new?
    true
  end

  def create?
    true
  end

  def destroy?
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
