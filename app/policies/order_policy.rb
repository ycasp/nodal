class OrderPolicy < ApplicationPolicy
  def index?
    true
  end

  def export?
    !pure_sales_rep?
  end

  def show?
    customer_owner? || member_can_view_order?
  end

  def download_pdf?
    show?
  end

  def edit?
    return false unless member_of_organisation?
    return true unless pure_sales_rep?

    # Pure rep: only own draft orders for assigned customers
    record.draft? && customer_in_carteira?(record.customer) && rep_owns_order?(record)
  end

  def update?
    edit?
  end

  def new?
    true
  end

  # Looking up a line to add, and what it would cost this customer. Reachable
  # from both the new and the edit screens, so there is no order to check
  # against — membership of the organisation in context is the gate, and the
  # controller only ever reads variants and customers belonging to it.
  def variant_search?
    user.is_a?(Member) && organisation.present? && user.organisations.include?(organisation)
  end

  def variant_pricing?
    variant_search?
  end

  def create?
    return false unless member_of_organisation?
    return true unless pure_sales_rep?

    # During #new there's no customer yet — allow the form. #create has it.
    record.customer.nil? || customer_in_carteira?(record.customer)
  end

  def destroy?
    return false unless member_of_organisation?
    return true unless pure_sales_rep?

    # Pure rep: only drafts they placed
    record.draft? && record.sales_rep_id == current_org_member&.id
  end

  def apply_discount?
    # Reps can't apply discretionary discounts in MVP (margin protection)
    return false if pure_sales_rep?

    member_of_organisation?
  end

  def remove_discount?
    return false if pure_sales_rep?

    member_of_organisation?
  end

  # Pricing the shipping is a back-office job: reps quote, they don't invoice.
  def set_shipping?
    return false if pure_sales_rep?

    member_of_organisation?
  end

  def retry_push?
    return false if pure_sales_rep?

    member_of_organisation?
  end

  # Customer storefront actions — also allow a sales rep impersonating the
  # empresa to act on the empresa's draft cart and placed-order shortcuts.
  def place?
    (customer_owner? || member_impersonating_order_customer?) && record.draft?
  end

  def clear?
    (customer_owner? || member_impersonating_order_customer?) && record.draft?
  end

  def checkout?
    (customer_owner? || member_impersonating_order_customer?) && record.draft?
  end

  def reorder?
    (customer_owner? || member_impersonating_order_customer?) && record.placed?
  end

  def add_to_cart?
    (customer_owner? || member_impersonating_order_customer?) && record.placed?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.is_a?(CustomerUser)
        scope.where(customer_user_id: user.id)
      elsif user.is_a?(Member)
        if pure_sales_rep?
          # Carteira orders only, and within that, only orders this rep placed
          # or self-service ones (sales_rep_id IS NULL). Orders placed by other
          # reps for shared customers stay hidden.
          scope.where(organisation: @organisation)
               .where(customer_id: assigned_customer_ids)
               .where("orders.sales_rep_id IS NULL OR orders.sales_rep_id = ?", current_org_member.id)
        else
          scope.joins(:organisation).where(organisations: { id: user.organisation_ids })
        end
      else
        scope.none
      end
    end
  end

  private

  def member_of_organisation?
    user.is_a?(Member) && user.organisations.include?(record.organisation)
  end

  def member_can_view_order?
    return false unless member_of_organisation?
    return true unless pure_sales_rep?

    customer_in_carteira?(record.customer) && rep_owns_order?(record)
  end

  def customer_owner?
    user.is_a?(CustomerUser) && record.customer_user_id == user.id
  end

  def member_impersonating_order_customer?
    return false unless user.is_a?(Member)
    return false unless context.is_a?(PunditContext) && context.impersonating?

    context.impersonated_customer_id.to_i == record.customer_id
  end
end
