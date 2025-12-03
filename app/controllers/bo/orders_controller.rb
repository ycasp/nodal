class Bo::OrdersController < Bo::BaseController

  def index
    @orders = policy_scope(Order)
  end

end
