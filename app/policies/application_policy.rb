# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :context, :user, :organisation, :record

  def initialize(context, record)
    @context = context
    @user = context.is_a?(PunditContext) ? context.user : context
    @organisation = context.is_a?(PunditContext) ? context.organisation : nil
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    attr_reader :context, :user, :organisation, :scope

    def initialize(context, scope)
      @context = context
      @user = context.is_a?(PunditContext) ? context.user : context
      @organisation = context.is_a?(PunditContext) ? context.organisation : nil
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    def user_is_a_member?
      return @user.is_a?(Member)
    end

    def member_working_for_organisation?
      return user_is_a_member? ? @user.organisations.include?(@organisation) : false
    end
  end

  private

  def user_is_a_member?
    return @user.is_a?(Member)
  end

  def member_working_for_organisation?
    return user_is_a_member? ? @user.organisations.include?(@organisation) : false
  end

  def record_belongs_to_user_organisation?
    if user_is_a_member?
      return @user.organisations.include?(record.organisation)
    else
      return false
    end
  end
end
