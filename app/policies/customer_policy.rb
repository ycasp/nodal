class CustomerPolicy < ApplicationPolicy

  def show?
    user_works_for_records_organisation?
  end

  def update?
    user_works_for_records_organisation?
  end

  def destroy?
    user_works_for_records_organisation?
  end

  def new?
    true
  end

  def create?
    user_works_for_records_organisation?
  end

  def invite?
    user_works_for_records_organisation?
  end

  class Scope < ApplicationPolicy::Scope
    # NOTE: Be explicit about which records you allow access to!
    def resolve
      number_of_distinct_organisations = scope.select("organisation_id").distinct.length
      if number_of_distinct_organisations <= 1
        scope.all
      else
        #
      end
    end
  end

  private

  def user_works_for_records_organisation?
    return user.organisations.include?(record.organisation)
  end
end
