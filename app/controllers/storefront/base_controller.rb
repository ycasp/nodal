class Storefront::BaseController < ApplicationController
  layout "customer"

  before_action :authenticate_customer!

  helper_method :current_cart, :cart_item_count, :cart_line_item_count, :active_order_discounts,
                :has_order_discounts?, :browsing_as_member?, :current_storefront_user

  def current_cart
    @current_cart ||= current_customer&.current_cart(current_organisation)
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

  # Returns true when a member is browsing the storefront (not a customer)
  def browsing_as_member?
    current_customer.nil? && current_member.present?
  end

  # Returns the current user (customer or member) browsing the storefront
  def current_storefront_user
    current_customer || current_member
  end

  private

  def authenticate_customer!
    # Allow customers
    return if current_customer.present? && current_customer.organisation == current_organisation

    # Allow members who belong to this organisation (browse-only)
    return if current_member.present? && current_member.organisations.exists?(current_organisation&.id)

    flash[:alert] = "Please sign in to continue."
    redirect_to new_customer_session_path(org_slug: params[:org_slug])
  end

  # Use in controllers that should be customer-only (cart, checkout)
  def require_customer!
    if browsing_as_member?
      flash[:alert] = t("storefront.member_browse.cart_not_available")
      redirect_to products_path(org_slug: current_organisation.slug)
    end
  end
end
