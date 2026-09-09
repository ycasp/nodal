require "csv"

class Bo::ProductsController < Bo::BaseController
  before_action :set_product, only: [:show, :edit, :update, :destroy, :configure_variants, :update_variant_configuration, :delete_photo]

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
    @products = policy_scope(current_organisation.products).includes(:categories)

    if params[:query].present?
      matching_ids = @products.left_joins(:categories).where(
        "products.name ILIKE :q OR products.sku ILIKE :q OR products.description ILIKE :q OR categories.name ILIKE :q",
        q: "%#{params[:query]}%"
      ).select("products.id").distinct
      @products = @products.where(id: matching_ids)
    end
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

  def delete_photo
    photo = @product.photos.find(params[:photo_id])
    photo.purge
    redirect_to edit_bo_product_path(params[:org_slug], @product), notice: t('bo.flash.image_deleted')
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

  private

  def set_product
    @product = current_organisation.products.find(params[:id])
    authorize @product
  end

  def product_params
    params.require(:product).permit(:name, :slug, :sku, :description, :price, :unit_description, :min_quantity, :min_quantity_type, :available, :category_id, category_ids: [], photos: [])
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
