class CustomerCategoryPolicy < ApplicationPolicy
  def index?
    member_working_for_organisation?
  end

  def show?
    member_working_for_organisation? && record_belongs_to_user_organisation?
  end

  def create?
    member_working_for_organisation?
  end

  def new?
    member_working_for_organisation?
  end

  def update?
    member_working_for_organisation? && record_belongs_to_user_organisation?
  end

  def destroy?
    member_working_for_organisation? && record_belongs_to_user_organisation?
  end

  def add_customers?
    update?
  end

  def remove_customer?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      raise Pundit::NotAuthorizedError unless member_working_for_organisation?
      scope.where(organisation: @organisation)
    end
  end
end
