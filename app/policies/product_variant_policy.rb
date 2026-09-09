class ProductVariantPolicy < ApplicationPolicy
  def index?
    belongs_to_organisation?
  end

  def show?
    belongs_to_organisation?
  end

  def new?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def create?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def edit?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def update?
    edit?
  end

  def destroy?
    !pure_sales_rep? && belongs_to_organisation? && record.order_items.empty?
  end

  private

  def belongs_to_organisation?
    return false if user.nil?

    if user.is_a?(Member)
      user.organisations.include?(record.organisation)
    else
      false
    end
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
