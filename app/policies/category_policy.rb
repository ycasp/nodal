class CategoryPolicy < ApplicationPolicy
  def index?
    member_working_for_organisation?
  end

  def show?
    belongs_to_organisation?
  end

  def new?
    member_working_for_organisation?
  end

  def create?
    member_working_for_organisation?
  end

  def edit?
    belongs_to_organisation?
  end

  def update?
    belongs_to_organisation?
  end

  def destroy?
    belongs_to_organisation? && record.deletable?
  end

  def move?
    belongs_to_organisation?
  end

  def restore?
    belongs_to_organisation?
  end

  def reorder?
    member_working_for_organisation?
  end

  def add_products?
    belongs_to_organisation?
  end

  def remove_product?
    belongs_to_organisation?
  end

  private

  def belongs_to_organisation?
    return false if user.nil?

    if user.is_a?(Member)
      user.organisations.include?(record.organisation)
    elsif user.is_a?(Customer)
      user.organisation == record.organisation
    else
      false
    end
  end

  def member_working_for_organisation?
    return false if user.nil? || !user.is_a?(Member)

    user.organisations.include?(organisation)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
