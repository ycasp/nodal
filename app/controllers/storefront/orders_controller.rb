class Storefront::OrdersController < Storefront::BaseController
  def index
    @orders = policy_scope(current_customer.orders.placed, policy_scope_class: OrderPolicy::Scope)
                .includes(:order_items, :products)
                .order(placed_at: :desc)
  end

  def show
    @order = current_customer.orders.find(params[:id])
    authorize @order
  end
end
