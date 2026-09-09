class Storefront::BaseController < ApplicationController
  layout "customer"

  before_action :authenticate_customer_user!
  before_action :touch_last_seen

  helper_method :current_cart, :cart_item_count, :cart_line_item_count, :active_order_discounts,
                :has_order_discounts?, :browsing_as_member?, :current_storefront_user,
                :impersonation_cart_user, :visible_orders_scope

  # The Order relation to display in storefront views. During impersonation,
  # the rep doesn't have their own CustomerUser session — orders are viewed
  # at empresa level. For normal customer logins, scoped to the logged-in
  # CustomerUser's personal order history.
  def visible_orders_scope
    if impersonating?
      current_customer.orders
    else
      current_customer_user&.orders || Order.none
    end
  end

  def current_cart
    @current_cart ||=
      if impersonating?
        impersonation_cart_user&.current_cart(current_organisation)
      else
        current_customer_user&.current_cart(current_organisation)
      end
  end

  # The CustomerUser whose cart we use while a rep is impersonating an empresa.
  # Falls back to the empresa's first existing CustomerUser (typically the
  # ERP-mirrored or rep-seeded stub). Memoised per-request.
  def impersonation_cart_user
    return nil unless impersonating?
    @impersonation_cart_user ||= impersonated_customer.customer_users.order(:id).first
  end

  def cart_item_count
    current_cart&.item_count || 0
  end

  def cart_line_item_count
    current_cart&.line_item_count || 0
  end

  def active_order_discounts
    @active_order_discounts ||= current_organisation.order_discounts.active.by_min_amount
  end

  def has_order_discounts?
    active_order_discounts.any?
  end

  # Returns true when a member is browsing the storefront WITHOUT an active
  # impersonation. When impersonating, the rep effectively IS the customer
  # for cart/checkout purposes — current_customer returns the empresa.
  def browsing_as_member?
    !impersonating? && current_customer_user.nil? && current_member.present?
  end

  # Returns the current user (customer or member) browsing the storefront
  def current_storefront_user
    current_customer || current_member
  end

  private

  # Updates the logged-in CustomerUser's last_seen_at on every storefront
  # request, throttled to one write per minute so navigation doesn't
  # hammer the DB. Skipped for impersonation/member browsing where there
  # is no real customer user signed in.
  def touch_last_seen
    return unless current_customer_user

    last = current_customer_user.last_seen_at
    return if last && last > 60.seconds.ago

    current_customer_user.update_column(:last_seen_at, Time.current)
  end

  # Re-prices the cart against current variant prices and active discounts
  # whenever the customer re-engages with cart/checkout, so an expired
  # discount or an ERP price change can't be carried silently into checkout.
  def refresh_cart_pricing
    @cart_changes = current_cart&.refresh_cart!
  end

  # True when the just-run refresh moved any line's price or discount.
  def cart_pricing_changed?
    @cart_changes.present? &&
      (@cart_changes[:price_changed].any? || @cart_changes[:discount_changed].any?)
  end

  def authenticate_customer_user!
    # Allow CustomerUsers whose Customer (empresa) belongs to this org
    return if current_customer_user.present? && current_customer_user.customer&.organisation == current_organisation

    # Allow members impersonating an empresa in this org (sales-rep flow)
    return if impersonating?

    # Allow members who belong to this organisation (browse-only)
    return if current_member.present? && current_member.organisations.exists?(current_organisation&.id)

    flash[:alert] = "Please sign in to continue."
    redirect_to new_customer_user_session_path(org_slug: params[:org_slug])
  end

  # Use in controllers that should be customer-only (cart, checkout).
  # An impersonating rep IS effectively the customer for that empresa, so
  # they pass this gate just like a logged-in CustomerUser would.
  def require_customer!
    if browsing_as_member?
      flash[:alert] = t("storefront.member_browse.cart_not_available")
      redirect_to products_path(org_slug: current_organisation.slug)
    end
  end
end
