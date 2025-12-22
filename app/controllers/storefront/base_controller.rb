class Storefront::BaseController < ApplicationController
  layout "customer"

  before_action :authenticate_customer!

  helper_method :current_cart, :cart_item_count, :active_order_discounts, :has_order_discounts?

  def current_cart
    @current_cart ||= current_customer&.current_cart(current_organisation)
  end

  def cart_item_count
    current_cart&.item_count || 0
  end

  def active_order_discounts
    @active_order_discounts ||= current_organisation.order_discounts.active.by_min_amount
  end

  def has_order_discounts?
    active_order_discounts.any?
  end

  private

  def authenticate_customer!
    return if current_customer.present? && current_customer.organisation == current_organisation

    flash[:alert] = "Please sign in to continue."
    redirect_to new_customer_session_path(org_slug: params[:org_slug])
  end
end
