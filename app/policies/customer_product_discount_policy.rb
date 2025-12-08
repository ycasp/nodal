class CustomerProductDiscountPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  def create?
    user_works_for_records_organisation?
  end

  def new?
    true
  end

  def edit?
    user_works_for_records_organisation?
  end

  def update?
    user_works_for_records_organisation?
  end

  def destroy?
    user_works_for_records_organisation?
  end

  class Scope < ApplicationPolicy::Scope
    # NOTE: Be explicit about which records you allow access to!
    def resolve
      scope.all
    end
  end

  def user_works_for_records_organisation?
    return user.organisations.include?(record.organisation)
  end
end
