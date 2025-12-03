class Bo::OrdersController < Bo::BaseController
  before_action :set_order, only: [:show, :edit, :update]

  def index
    @orders = policy_scope(Order)
  end

  def show
  end

  def edit
  end

  def update
    if @order.update(order_params)
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id), notice: "Order updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
    authorize @order
  end

  def order_params
    params.require(:order).permit(:status, :payment_status, :receive_on, :notes)
  end
end
