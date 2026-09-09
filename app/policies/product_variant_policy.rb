class ProductVariantPolicy < ApplicationPolicy
  def index?
    belongs_to_organisation?
  end

  def show?
    belongs_to_organisation?
  end

  def new?
    belongs_to_organisation?
  end

  def create?
    belongs_to_organisation?
  end

  def edit?
    belongs_to_organisation?
  end

  def update?
    belongs_to_organisation?
  end

  def destroy?
    belongs_to_organisation? && record.order_items.empty?
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
