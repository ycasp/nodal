class Bo::HomepageSettingsController < Bo::BaseController
  before_action :set_and_authorize_organisation

  def edit
    load_data
  end

  def update
    if @organisation.update(homepage_organisation_params)
      redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.flash.settings_updated')
    else
      load_data
      flash.now[:alert] = @organisation.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  # Banners
  def create_banner
    banner = @organisation.homepage_banners.build(banner_params)
    if banner.save
      redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.banner_created')
    else
      load_data
      flash.now[:alert] = banner.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def update_banner
    banner = @organisation.homepage_banners.find(params[:banner_id])
    if banner.update(banner_params)
      redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.banner_updated')
    else
      load_data
      flash.now[:alert] = banner.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_banner
    banner = @organisation.homepage_banners.find(params[:banner_id])
    banner.update!(active: !banner.active?)
    redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug)
  end

  def destroy_banner
    banner = @organisation.homepage_banners.find(params[:banner_id])
    banner.destroy
    redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.banner_deleted')
  end

  # Featured Products
  def add_featured_products
    product_ids = params[:product_ids] || []
    products = @organisation.products.where(id: product_ids)

    products.each do |product|
      @organisation.homepage_featured_products.find_or_create_by(product: product)
    end

    redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.products_added', count: products.count)
  end

  def remove_featured_product
    @organisation.homepage_featured_products.find_by(product_id: params[:product_id])&.destroy
    redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.product_removed')
  end

  # Featured Categories
  def add_featured_categories
    category_ids = params[:category_ids] || []
    categories = @organisation.categories.kept.where(id: category_ids)

    categories.each do |category|
      @organisation.homepage_featured_categories.find_or_create_by(category: category)
    end

    redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.categories_added', count: categories.count)
  end

  def remove_featured_category
    @organisation.homepage_featured_categories.find_by(category_id: params[:category_id])&.destroy
    redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.category_removed')
  end

  # Special Price Products (homepage section showing products with active discounts)
  def add_special_price_products
    product_ids = params[:product_ids] || []
    # Only allow products that actually have an active discount somewhere.
    eligible_ids = discountable_product_ids(@organisation) & product_ids.map(&:to_i)
    products = @organisation.products.where(id: eligible_ids)

    products.each do |product|
      @organisation.homepage_special_price_products.find_or_create_by(product: product)
    end

    redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.special_price_products_added', count: products.count)
  end

  def remove_special_price_product
    @organisation.homepage_special_price_products.find_by(product_id: params[:product_id])&.destroy
    redirect_to edit_bo_homepage_settings_path(org_slug: @organisation.slug), notice: t('bo.homepage_settings.flash.special_price_product_removed')
  end

  private

  # Product IDs in this organisation that have at least one active discount.
  # Includes:
  #   - product-specific ProductDiscount
  #   - category-level ProductDiscount (covers any category in the product's path)
  #   - any active CustomerProductDiscount (per-customer or per-customer-category)
  # OrderDiscount and CustomerDiscount (tier) are excluded — they don't single
  # out a specific product, so they're not the basis for a "special price" badge.
  def discountable_product_ids(org)
    direct_pd_ids = ProductDiscount.active.for_product.where(organisation: org).pluck(:product_id)
    pd_category_ids = ProductDiscount.active.for_category.where(organisation: org).pluck(:category_id)

    direct_cpd_ids = CustomerProductDiscount.active.for_product.where(organisation: org).pluck(:product_id)
    cpd_category_ids = CustomerProductDiscount.active.for_category.where(organisation: org).pluck(:category_id)

    cat_product_ids = expand_category_ids_to_product_ids(org, (pd_category_ids + cpd_category_ids).uniq)

    (direct_pd_ids + direct_cpd_ids + cat_product_ids).uniq
  end

  def expand_category_ids_to_product_ids(org, category_ids)
    return [] if category_ids.empty?

    # Mirror DiscountCalculator behaviour: a discount on a parent category
    # applies to all descendant categories' products too.
    all_cat_ids = org.categories.where(id: category_ids).flat_map(&:subtree_ids).uniq
    return [] if all_cat_ids.empty?

    CategoryProduct.where(category_id: all_cat_ids).pluck(:product_id)
  end

  def set_and_authorize_organisation
    @organisation = current_organisation
    authorize @organisation, :update?, policy_class: SettingPolicy
  end

  def load_data
    @banners = @organisation.homepage_banners.by_position.includes(image_attachment: :blob)
    @featured_products = @organisation.homepage_featured_products.order(:position).includes(product: { photos_attachments: :blob })
    @featured_categories = @organisation.homepage_featured_categories.order(:position).includes(:category)
    @special_price_products = @organisation.homepage_special_price_products.order(:position).includes(product: { photos_attachments: :blob })
    @discountable_product_ids = discountable_product_ids(@organisation)
  end

  def banner_params
    params.require(:homepage_banner).permit(:image, :title, :subtitle, :link_url, :link_text, :active, :text_theme)
  end

  def homepage_organisation_params
    params.require(:organisation).permit(
      :special_prices_show_price,
      :special_prices_show_discount_badge,
      :special_prices_show_sale_badge
    )
  end
end
