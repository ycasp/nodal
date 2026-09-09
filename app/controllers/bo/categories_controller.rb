class Bo::CategoriesController < Bo::BaseController
  before_action :set_category, only: [:show, :edit, :update, :destroy, :move, :restore, :add_products, :remove_product]

  def index
    @categories = policy_scope(current_organisation.categories.kept.roots.by_position)
  end

  def show
    @products = @category.products.includes(:photo_attachment)
    @subcategories = @category.children.kept.by_position
  end

  def new
    @category = Category.new
    @category.parent_id = params[:parent_id] if params[:parent_id].present?
    authorize @category
  end

  def create
    @category = Category.new(category_params)
    @category.organisation = current_organisation
    authorize @category

    if @category.save
      redirect_to bo_categories_path(params[:org_slug]), notice: t('bo.flash.category_created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to bo_categories_path(params[:org_slug]), notice: t('bo.flash.category_updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.deletable?
      @category.discard
      redirect_to bo_categories_path(params[:org_slug]), notice: t('bo.flash.category_deleted')
    else
      redirect_to bo_categories_path(params[:org_slug]), alert: t('bo.flash.category_has_children')
    end
  end

  def move
    target_parent_id = params[:parent_id].presence
    new_position = params[:position].to_i

    # Update parent if changed
    if target_parent_id.nil?
      @category.update(ancestry: nil)
    else
      target_parent = current_organisation.categories.find(target_parent_id)
      @category.update(parent: target_parent)
    end

    # Update position
    @category.insert_at(new_position + 1)

    head :ok
  end

  def restore
    @category.undiscard
    redirect_to bo_categories_path(params[:org_slug]), notice: t('bo.flash.category_restored')
  end

  def add_products
    product_ids = params[:product_ids] || []
    products = current_organisation.products.where(id: product_ids)

    products.each do |product|
      @category.products << product unless @category.products.include?(product)
    end

    redirect_to bo_category_path(params[:org_slug], @category), notice: t('bo.flash.products_added_to_category', count: products.count)
  end

  def remove_product
    product = current_organisation.products.find(params[:product_id])
    @category.products.delete(product)

    redirect_to bo_category_path(params[:org_slug], @category), notice: t('bo.flash.product_removed_from_category', name: product.name)
  end

  def reorder
    category_ids = params[:category_ids] || []

    category_ids.each_with_index do |id, index|
      current_organisation.categories.find(id).update(position: index + 1)
    end

    head :ok
  end

  private

  def set_category
    @category = current_organisation.categories.find(params[:id])
    authorize @category
  end

  def category_params
    params.require(:category).permit(:name, :description, :color, :parent_id, :slug, :metadata)
  end
end
