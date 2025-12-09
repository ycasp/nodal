class ProductDiscountPolicy < ApplicationPolicy
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

  def toggle_active?
    user_works_for_records_organisation?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  private

  def user_works_for_records_organisation?
    user.organisations.include?(record.organisation)
  end
end
