class OrderPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    customer_owner? || member_of_organisation?
  end

  def edit?
    member_of_organisation?
  end

  def update?
    member_of_organisation?
  end

  def new?
    true
  end

  def create?
    member_of_organisation?
  end

  def destroy?
    member_of_organisation?
  end

  # Customer storefront actions
  def place?
    customer_owner? && record.draft?
  end

  def clear?
    customer_owner? && record.draft?
  end

  def checkout?
    customer_owner? && record.draft?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.is_a?(Customer)
        scope.where(customer: user)
      elsif user.is_a?(Member)
        scope.joins(:organisation).where(organisations: { id: user.organisation_ids })
      else
        scope.none
      end
    end
  end

  private

  def member_of_organisation?
    user.is_a?(Member) && user.organisations.include?(record.organisation)
  end

  def customer_owner?
    user.is_a?(Customer) && record.customer == user
  end
end
