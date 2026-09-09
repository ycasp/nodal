class DiscountEmailNotificationPolicy < ApplicationPolicy
  def send_email?
    user_works_for_records_organisation?
  end

  private

  def user_works_for_records_organisation?
    user.organisations.include?(record.organisation)
  end
end
