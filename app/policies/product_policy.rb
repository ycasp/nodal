class ProductPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  def show?
    belongs_to_organisation?
  end

  def new?
    true
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
    belongs_to_organisation?
  end

  private

  def belongs_to_organisation?
    user.organisations.include?(record.organisation)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      number_of_companies = scope.select("organisation_id").distinct.length
      if number_of_companies == 1
        scope.all
      else
        # raise an error
      end
    end
  end
end
