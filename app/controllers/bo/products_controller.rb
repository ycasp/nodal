require "csv"

class Bo::ProductsController < Bo::BaseController
  before_action :set_product, only: [:show, :edit, :update, :destroy, :configure_variants, :update_variant_configuration, :delete_photo, :set_main_photo, :related_products, :update_related_products, :reorder_related_products]

  # Import actions
  def import
    authorize Product, :create?
  end

  def import_mapping
    authorize Product, :create?

    unless params[:file].present?
      redirect_to import_bo_products_path(params[:org_slug]), alert: t("bo.products.import.no_file")
      return
    end

    begin
      csv_content = params[:file].read.force_encoding("UTF-8")
      csv_content = csv_content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

      # Auto-detect delimiter (semicolon common in European Excel exports)
      col_sep = detect_csv_delimiter(csv_content)

      # Parse CSV to get headers
      csv = CSV.parse(csv_content, headers: true, col_sep: col_sep)
      @csv_headers = csv.headers.compact.reject(&:blank?)
      @preview_row = csv.first&.to_h || {}

      # Store CSV content in temp file and delimiter in session
      @import_key = SecureRandom.uuid
      temp_path = Rails.root.join("tmp", "imports", "#{@import_key}.csv")
      FileUtils.mkdir_p(temp_path.dirname)
      File.write(temp_path, csv_content)
      session["import_#{@import_key}_col_sep"] = col_sep

      @importable_fields = ProductImportService.importable_fields
    rescue CSV::MalformedCSVError => e
      redirect_to import_bo_products_path(params[:org_slug]), alert: t("bo.products.import.invalid_csv", error: e.message)
    end
  end

  def import_process
    authorize Product, :create?

    import_key = params[:import_key]
    mapping = params[:mapping]&.to_unsafe_h || {}

    temp_path = Rails.root.join("tmp", "imports", "#{import_key}.csv")

    unless File.exist?(temp_path)
      redirect_to import_bo_products_path(params[:org_slug]), alert: t("bo.products.import.session_expired")
      return
    end

    csv_content = File.read(temp_path)
    col_sep = session["import_#{import_key}_col_sep"] || ","

    service = ProductImportService.new(
      organisation: current_organisation,
      csv_content: csv_content,
      column_mapping: mapping,
      col_sep: col_sep
    )

    @result = service.call

    # Clean up temp file and session
    File.delete(temp_path) if File.exist?(temp_path)
    session.delete("import_#{import_key}_col_sep")

    render :import_results
  end

  def index
    @products = policy_scope(current_organisation.products).includes(:categories, :product_variants).with_attached_photos

    if params[:query].present?
      matching_ids = @products.left_joins(:categories, :product_variants).where(
        "unaccent(products.name) ILIKE unaccent(:q) OR unaccent(products.sku) ILIKE unaccent(:q) OR unaccent(products.description) ILIKE unaccent(:q) OR unaccent(categories.name) ILIKE unaccent(:q) OR unaccent(product_variants.sku) ILIKE unaccent(:q)",
        q: "%#{params[:query]}%"
      ).select("products.id").distinct
      @products = @products.where(id: matching_ids)
    end

    # Category filter
    if params[:category_id] == "none"
      product_ids_with_category = CategoryProduct.select(:product_id)
      @products = @products.where.not(id: product_ids_with_category)
    elsif params[:category_id].present?
      category = current_organisation.categories.kept.find_by(id: params[:category_id])
      if category
        @current_category = category
        all_category_ids = category.subtree_ids
        product_ids_in_category = CategoryProduct.where(category_id: all_category_ids).select(:product_id)
        @products = @products.where(id: product_ids_in_category)
      end
    end

    # Product type filter
    if params[:product_type].present?
      case params[:product_type]
      when "simple" then @products = @products.simple
      when "variable" then @products = @products.variable
      end
    end

    # Price status filter
    case params[:price_status]
    when "on_request" then @products = @products.where(price_on_request: true)
    when "zero_price" then @products = @products.where(price_on_request: false, unit_price: [nil, 0])
    when "has_price" then @products = @products.where(price_on_request: false).where("unit_price > 0")
    end

    # Status filter
    case params[:status]
    when "available"
      @products = @products.where(available: true).where.not(
        id: Product.joins(:product_variants).where(has_variants: true, product_variants: { available: false }).select(:id)
      )
    when "unavailable"
      @products = @products.where(available: false)
    when "partial"
      @products = @products.where(has_variants: true, available: true).where(
        id: Product.joins(:product_variants).where(has_variants: true, product_variants: { available: false }).select(:id)
      )
    end

    # Sorting
    @sort_column = %w[name sku unit_price has_variants available].include?(params[:sort]) ? params[:sort] : "name"
    @sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
    @products = @products.order(@sort_column => @sort_direction)

    @pagy, @products = pagy(@products)

    # Load categories for filter dropdown
    @categories = current_organisation.categories.kept.order(:name)

    # Load last ERP product sync log (if ERP enabled)
    @last_product_sync = current_organisation.erp_sync_logs.for_entity('products').completed.recent.first if current_organisation.erp_configuration&.enabled?
  end

  def show
  end

  def new
    @product = Product.new
    if params[:category_id].present?
      category = current_organisation.categories.kept.find_by(id: params[:category_id])
      @product.category_ids = [category.id] if category
    end
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
    update_params = product_params
    new_photos = update_params.delete(:photos)
    new_photos = nil if new_photos.blank? || new_photos == [""]

    if @product.update(update_params)
      @product.photos.attach(new_photos) if new_photos
      redirect_to bo_product_path(params[:org_slug], @product, filter_params_hash), notice: "Product was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @product.destroy
      redirect_to bo_products_path(params[:org_slug], filter_params_hash), notice: "Product was successfully deleted."
    else
      redirect_to bo_product_path(params[:org_slug], @product, filter_params_hash), alert: @product.errors.full_messages.to_sentence
    end
  end

  def delete_photo
    photo = @product.photos.find(params[:photo_id])
    photo.purge
    redirect_to edit_bo_product_path(params[:org_slug], @product), notice: t('bo.flash.image_deleted')
  end

  def set_main_photo
    @product.update!(cover_photo_blob_id: params[:photo_id].to_i)
    redirect_to edit_bo_product_path(params[:org_slug], @product), notice: t('bo.flash.main_photo_set')
  end

  def configure_variants
    @available_attributes = current_organisation.product_attributes.kept.active.by_position.includes(:product_attribute_values)
  end

  def update_variant_configuration
    has_variants = params[:has_variants] == '1'
    attribute_ids = params.dig(:product, :product_attribute_ids)&.reject(&:blank?) || []
    available_value_ids = params.dig(:product, :available_attribute_value_ids)&.reject(&:blank?) || []

    ActiveRecord::Base.transaction do
      # Update has_variants flag
      @product.update!(has_variants: has_variants)

      # Update assigned attributes
      @product.product_product_attributes.destroy_all
      attribute_ids.each_with_index do |attr_id, index|
        @product.product_product_attributes.create!(product_attribute_id: attr_id, position: index + 1)
      end

      # Update available values
      @product.product_available_values.destroy_all
      available_value_ids.each do |value_id|
        @product.product_available_values.create!(product_attribute_value_id: value_id)
      end
    end

    redirect_to configure_variants_bo_product_path(params[:org_slug], @product), notice: t('bo.flash.variant_configuration_updated')
  rescue ActiveRecord::RecordInvalid => e
    @available_attributes = current_organisation.product_attributes.kept.active.by_position.includes(:product_attribute_values)
    flash.now[:alert] = e.message
    render :configure_variants, status: :unprocessable_entity
  end

  def related_products
    # Get related product IDs in order
    related_ids = @product.related_product_associations.order(:position).pluck(:related_product_id)

    # Fetch products and preserve order
    if related_ids.any?
      products_by_id = Product.where(id: related_ids).index_by(&:id)
      @selected_products = related_ids.map { |id| products_by_id[id] }.compact
    else
      @selected_products = []
    end

    @available_products = current_organisation.products
                                               .where.not(id: [@product.id] + related_ids)
                                               .where(available: true)
                                               .order(:name)
  end

  def update_related_products
    related_product_ids = params[:related_product_ids]&.reject(&:blank?) || []
    hide_related_products = params[:hide_related_products] == "1"

    ActiveRecord::Base.transaction do
      @product.update!(hide_related_products: hide_related_products)

      @product.related_product_associations.destroy_all
      related_product_ids.each_with_index do |product_id, index|
        @product.related_product_associations.create!(related_product_id: product_id, position: index + 1)
      end
    end

    redirect_to related_products_bo_product_path(params[:org_slug], @product), notice: t("bo.products.related.updated")
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = e.message
    redirect_to related_products_bo_product_path(params[:org_slug], @product)
  end

  def reorder_related_products
    positions = params[:positions] || []

    ActiveRecord::Base.transaction do
      positions.each_with_index do |product_id, index|
        association = @product.related_product_associations.find_by(related_product_id: product_id)
        association&.update!(position: index + 1)
      end
    end

    head :ok
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  helper_method :filter_params_hash, :sort_link_params

  private

  def filter_params_hash
    { query: params[:query], category_id: params[:category_id], product_type: params[:product_type],
      price_status: params[:price_status], status: params[:status], sort: params[:sort], direction: params[:direction] }.compact_blank
  end

  def sort_link_params(column)
    direction = (@sort_column == column && @sort_direction == "asc") ? "desc" : "asc"
    filter_params_hash.merge(sort: column, direction: direction)
  end

  def set_product
    @product = current_organisation.products.includes(:product_variants).find(params[:id])
    authorize @product
  end

  def product_params
    params.require(:product).permit(:name, :slug, :sku, :description, :price, :unit_description, :min_quantity, :min_quantity_type, :available, :price_on_request, :category_id, category_ids: [], photos: [])
  end

  def detect_csv_delimiter(content)
    # Sample first 1024 bytes to detect delimiter
    sample = content[0, 1024] || content
    # Count occurrences of common delimiters in first line
    first_line = sample.lines.first || ""
    semicolons = first_line.count(";")
    commas = first_line.count(",")
    tabs = first_line.count("\t")

    if semicolons > commas && semicolons > tabs
      ";"
    elsif tabs > commas && tabs > semicolons
      "\t"
    else
      ","
    end
  end
end
