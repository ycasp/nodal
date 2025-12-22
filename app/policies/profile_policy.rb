class ProfilePolicy < ApplicationPolicy
  # Members can only edit their own profile
  def edit?
    user == record
  end

  def update?
    user == record
  end
end
