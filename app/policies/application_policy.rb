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

    private

    def current_org_member
      return @current_org_member if defined?(@current_org_member)

      @current_org_member =
        if user_is_a_member? && @organisation
          OrgMember.find_by(member_id: @user.id, organisation_id: @organisation.id)
        end
    end

    def admin_or_owner?
      current_org_member&.role&.in?(%w[admin owner])
    end

    def sales_rep?
      !!current_org_member&.is_sales_rep?
    end

    # A "pure rep" is a sales_rep whose team role is plain `member` — they have
    # no org-level powers, only carteira capabilities. Owners/admins who are
    # also reps keep their full powers; only their carteira UI is scoped.
    def pure_sales_rep?
      sales_rep? && current_org_member.role == 'member'
    end

    def assigned_customer_ids
      return [] unless sales_rep?

      @assigned_customer_ids ||= current_org_member.customer_assignments.pluck(:customer_id)
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

  def current_org_member
    return @current_org_member if defined?(@current_org_member)

    @current_org_member =
      if user_is_a_member? && @organisation
        OrgMember.find_by(member_id: @user.id, organisation_id: @organisation.id)
      end
  end

  def admin_or_owner?
    current_org_member&.role&.in?(%w[admin owner])
  end

  def sales_rep?
    !!current_org_member&.is_sales_rep?
  end

  # A "pure rep" is a sales_rep whose team role is plain `member` — they have
  # no org-level powers, only carteira capabilities. Owners/admins who are
  # also reps keep their full powers; only their carteira UI is scoped.
  def pure_sales_rep?
    sales_rep? && current_org_member.role == 'member'
  end

  def assigned_customer_ids
    return [] unless sales_rep?

    @assigned_customer_ids ||= current_org_member.customer_assignments.pluck(:customer_id)
  end

  def customer_in_carteira?(customer)
    sales_rep? && customer && assigned_customer_ids.include?(customer.id)
  end

  def rep_owns_order?(order)
    return true unless pure_sales_rep?

    order.sales_rep_id.nil? || order.sales_rep_id == current_org_member.id
  end
end
