class CategoryPolicy < ApplicationPolicy
  def index?
    member_working_for_organisation?
  end

  def show?
    belongs_to_organisation?
  end

  def new?
    !pure_sales_rep? && member_working_for_organisation?
  end

  def create?
    !pure_sales_rep? && member_working_for_organisation?
  end

  def edit?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def update?
    edit?
  end

  def destroy?
    !pure_sales_rep? && belongs_to_organisation? && record.deletable?
  end

  def move?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def restore?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def reorder?
    !pure_sales_rep? && member_working_for_organisation?
  end

  def add_products?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def remove_product?
    !pure_sales_rep? && belongs_to_organisation?
  end

  private

  def belongs_to_organisation?
    return false if user.nil?

    if user.is_a?(Member)
      user.organisations.include?(record.organisation)
    elsif user.is_a?(CustomerUser)
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
