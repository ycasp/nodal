class CustomerPolicy < ApplicationPolicy
  def show?
    true
  end

  def update?
    user.organisations.include?(record.organisation)
  end

  def destroy?
    user.organisations.include?(record.organisation)
  end

  class Scope < ApplicationPolicy::Scope
    # NOTE: Be explicit about which records you allow access to!
    def resolve
      scope.all
    end

  end
end
