class Storefront::OrdersController < Storefront::BaseController
  before_action :require_customer!

  def index
    @orders = policy_scope(current_customer.orders.placed, policy_scope_class: OrderPolicy::Scope)
                .includes(:order_items, :products)
                .order(placed_at: :desc)
  end

  def show
    @order = current_customer.orders.find(params[:id])
    authorize @order
  end

  def reorder
    original_order = current_customer.orders.placed.find(params[:id])
    authorize original_order

    # If cart has items and no confirmation, redirect back with warning
    if current_cart.order_items.any? && params[:confirm] != "true"
      flash[:alert] = "Your cart has items. Reordering will replace them. Press reorder again!"
      redirect_to order_path(org_slug: params[:org_slug], id: original_order, confirm_reorder: true)
      return
    end

    cart = current_cart
    skipped_items = []

    # Clear existing cart items
    cart.order_items.destroy_all

    # Group items by product+variant to handle potential duplicates in original order
    items_to_add = {}

    original_order.order_items.includes(:product, :product_variant).each do |item|
      product = item.product

      if product.nil? || !product.available?
        skipped_items << item.product&.name || "Unknown product"
        next
      end

      # Check if variant is still available
      variant = item.product_variant
      if variant.present? && !variant.purchasable?
        skipped_items << "#{product.name} (#{variant.option_values_string})"
        next
      end

      # Use product_id + variant_id as key to aggregate quantities
      key = [product.id, variant&.id]
      if items_to_add[key]
        items_to_add[key][:quantity] += item.quantity
      else
        items_to_add[key] = {
          product: product,
          product_variant: variant,
          quantity: item.quantity
        }
      end
    end

    # Create cart items
    items_to_add.each_value do |attrs|
      cart.order_items.create!(
        product: attrs[:product],
        product_variant: attrs[:product_variant],
        quantity: attrs[:quantity]
      )
    end

    if skipped_items.any?
      flash[:warning] = "Some items were unavailable and skipped: #{skipped_items.join(', ')}"
    else
      flash[:notice] = "Items from order #{original_order.order_number} added to your cart."
    end

    redirect_to cart_path(org_slug: params[:org_slug])
  end

  def add_to_cart
    original_order = current_customer.orders.placed.find(params[:id])
    authorize original_order

    cart = current_cart
    skipped_items = []

    original_order.order_items.includes(:product, :product_variant).each do |item|
      product = item.product

      if product.nil? || !product.available?
        skipped_items << item.product&.name || "Unknown product"
        next
      end

      variant = item.product_variant
      if variant.present? && !variant.purchasable?
        skipped_items << "#{product.name} (#{variant.option_values_string})"
        next
      end

      # Check if product+variant already exists in cart
      existing = cart.order_items.find_by(product: product, product_variant: variant)
      if existing
        existing.update!(quantity: existing.quantity + item.quantity)
      else
        cart.order_items.create!(
          product: product,
          product_variant: variant,
          quantity: item.quantity
        )
      end
    end

    if skipped_items.any?
      flash[:warning] = I18n.t('storefront.orders.add_to_cart.skipped', items: skipped_items.join(', '))
    else
      flash[:notice] = I18n.t('storefront.orders.add_to_cart.success', order_number: original_order.order_number)
    end

    redirect_to cart_path(org_slug: params[:org_slug])
  end
end
