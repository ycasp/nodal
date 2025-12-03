class Bo::CustomersController < Bo::BaseController

  def index
    @customers=policy_scope(Customer)
    @customers=Customer.all
  end

  def show
    @customers=policy_scope(Customer)
    
  end

end
