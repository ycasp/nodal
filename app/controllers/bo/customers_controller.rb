class Bo::CustomersController < Bo::BaseController

  def index
    @customers = policy_scope(Customer)
    if params[:query].present?
      @customers = @customers.where(
        "company_name ILIKE :q OR contact_name ILIKE :q OR email ILIKE :q",
        q: "%#{params[:query]}%"
      )
    end
  end

  def show
    @customer = Customer.find(params[:id])
    authorize @customer
  end

  def edit
    @customer = Customer.find(params[:id])
    authorize @customer
  end

  def update
    @customer = Customer.find(params[:id])
    authorize @customer
    if @customer.update(customer_params)
      redirect_to bo_customer_path(params[:org_slug], @customer), notice: "Customer updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer = Customer.find(params[:id])
    authorize @customer
    @customer.destroy
    redirect_to bo_customers_path(params[:org_slug]), status: :see_other, notice: "Customer deleted successfully."
  end

  private

  def customer_params
    params.require(:customer).permit(:company_name, :contact_name, :email, :contact_phone, :active)
  end

end
