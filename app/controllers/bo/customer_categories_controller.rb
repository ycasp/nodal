class Bo::CustomerCategoriesController < Bo::BaseController
  before_action :set_and_authorize_category, only: [:edit, :update, :destroy, :add_customers, :remove_customer]

  def new
    @customer_category = CustomerCategory.new
    authorize @customer_category
  end

  def create
    @customer_category = CustomerCategory.new(category_params)
    @customer_category.organisation = current_organisation
    authorize @customer_category

    if @customer_category.save
      redirect_to edit_bo_customer_category_path(params[:org_slug], @customer_category),
                  notice: t('bo.customer_categories.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_customers_for_edit
  end

  def update
    if @customer_category.update(category_params)
      redirect_to edit_bo_customer_category_path(params[:org_slug], @customer_category),
                  notice: t('bo.customer_categories.flash.updated')
    else
      load_customers_for_edit
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer_category.destroy
    redirect_to bo_customers_path(params[:org_slug], tab: 'categories'),
                status: :see_other,
                notice: t('bo.customer_categories.flash.deleted')
  end

  def add_customers
    customers = current_organisation.customers.where(id: params[:customer_ids])
    customers.update_all(customer_category_id: @customer_category.id)
    redirect_to edit_bo_customer_category_path(params[:org_slug], @customer_category),
                notice: t('bo.customer_categories.flash.customers_added')
  end

  def remove_customer
    customer = current_organisation.customers.find(params[:customer_id])
    customer.update!(customer_category_id: nil)
    redirect_to edit_bo_customer_category_path(params[:org_slug], @customer_category),
                notice: t('bo.customer_categories.flash.customer_removed')
  end

  private

  def category_params
    params.require(:customer_category).permit(:name, :description)
  end

  def set_and_authorize_category
    @customer_category = current_organisation.customer_categories.find(params[:id])
    authorize @customer_category
  end

  def load_customers_for_edit
    @assigned_customers = @customer_category.customers.order(:company_name)
    @available_customers = current_organisation.customers
                             .where(customer_category_id: [nil])
                             .where.not(id: @assigned_customers.select(:id))
                             .order(:company_name)
  end
end
