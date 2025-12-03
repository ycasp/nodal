class Bo::ProductsController < Bo::BaseController
  before_action :set_product, only: [:show, :edit, :update, :destroy]

  def index
    @products = policy_scope(current_organisation.products)

    if params[:query].present?
      @products = @products.joins(:category).where(
        "products.name ILIKE :q OR products.sku ILIKE :q OR products.description ILIKE :q OR categories.name ILIKE :q",
        q: "%#{params[:query]}%"
      )
    end
  end

  def show
  end

  def new
    @product = Product.new
    authorize @product
  end

  def create
    @product = Product.new(product_params)
    @product.organisation = current_organisation
    authorize @product

    if @product.save
      redirect_to bo_product_path(params[:org_slug], @product), notice: "Product was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to bo_product_path(params[:org_slug], @product), notice: "Product was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to bo_products_path(params[:org_slug]), notice: "Product was successfully deleted."
  end

  private

  def set_product
    @product = current_organisation.products.find(params[:id])
    authorize @product
  end

  def product_params
    params.require(:product).permit(:name, :slug, :sku, :description, :price, :unit_description, :min_quantity, :min_quantity_type, :available, :category_id, :photo)
  end
end
