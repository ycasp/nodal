class CustomerDiscountPolicy < ApplicationPolicy
  def create?
    !pure_sales_rep? && user_works_for_records_organisation?
  end

  def new?
    !pure_sales_rep?
  end

  def edit?
    !pure_sales_rep? && user_works_for_records_organisation?
  end

  def update?
    edit?
  end

  def destroy?
    !pure_sales_rep? && user_works_for_records_organisation?
  end

  def toggle_active?
    !pure_sales_rep? && user_works_for_records_organisation?
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
