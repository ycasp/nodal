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
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
