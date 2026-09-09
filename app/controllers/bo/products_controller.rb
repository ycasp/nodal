require "csv"

class Bo::ProductsController < Bo::BaseController
  include Exportable

  RELATED_PRODUCTS_PER_PAGE = 30

  before_action :set_product, only: [:show, :edit, :update, :destroy, :configure_variants, :update_variant_configuration, :delete_photo, :set_main_photo, :related_products, :related_products_search, :update_related_products, :reorder_related_products]
  before_action :load_attributes_for_form, only: [:new, :edit, :create, :update]

  # Add products choice page
  def add_products
    authorize Product, :add_products?
  end

  # Bulk create with spreadsheet grid
  def bulk_create
    authorize Product, :bulk_create?
    @categories = current_organisation.categories.kept.sorted_by_full_path
    @product_attributes = current_organisation.product_attributes.kept.active.by_position
                            .includes(:product_attribute_values)
    @all_skus = current_organisation.products.pluck(:sku).compact
    @variable_skus = current_organisation.products.where(has_variants: true).pluck(:sku).compact
  end

  def bulk_create_process
    authorize Product, :bulk_create_process?
    raw_rows = params.require(:rows)
    rows = raw_rows.to_unsafe_h.values.map(&:to_h)

    # Handle photo uploads
    zip_path = nil
    images_dir = nil
    import_key = SecureRandom.uuid

    if params[:zip_file].present?
      zip_path = Rails.root.join("tmp", "imports", "#{import_key}.zip").to_s
      FileUtils.mkdir_p(File.dirname(zip_path))
      File.open(zip_path, "wb") { |f| f.write(params[:zip_file].read) }
    end

    if params[:image_files].present?
      images_dir = Rails.root.join("tmp", "imports", "images_#{import_key}").to_s
      FileUtils.mkdir_p(images_dir)
      params[:image_files].each do |image|
        safe_name = image.original_filename.tr("/:", "--")
        File.open(File.join(images_dir, safe_name), "wb") { |f| f.write(image.read) }
      end
    end

    task = current_organisation.background_tasks.create!(
      member: current_member,
      task_type: "product_grid_import",
      status: :pending,
      total: rows.size
    )

    ProductGridImportJob.perform_later(
      task.id,
      organisation_id: current_organisation.id,
      rows: rows,
      zip_path: zip_path,
      images_dir: images_dir,
      photo_mode: params[:photo_mode] || "append"
    )

    redirect_to bo_background_task_path(params[:org_slug], task)
  end

  # Bulk photo upload
  def bulk_photos
    authorize Product, :bulk_photos?
    @all_skus = current_organisation.products.pluck(:sku).compact_blank +
                current_organisation.product_variants.where.not(sku: [nil, ""]).pluck(:sku)
  end

  def bulk_photos_process
    authorize Product, :bulk_photos_process?

    zip_path = nil
    images_dir = nil
    import_key = SecureRandom.uuid
    photo_mode = params[:photo_mode] || "append"

    if params[:zip_file].present?
      zip_path = Rails.root.join("tmp", "imports", "#{import_key}.zip").to_s
      FileUtils.mkdir_p(File.dirname(zip_path))
      File.open(zip_path, "wb") { |f| f.write(params[:zip_file].read) }
    end

    if params[:image_files].present?
      images_dir = Rails.root.join("tmp", "imports", "images_#{import_key}").to_s
      FileUtils.mkdir_p(images_dir)
      params[:image_files].each do |image|
        safe_name = image.original_filename.tr("/:", "--")
        File.open(File.join(images_dir, safe_name), "wb") { |f| f.write(image.read) }
      end
    end

    task = current_organisation.background_tasks.create!(
      member: current_member,
      task_type: "bulk_photo_import",
      status: :pending
    )

    BulkPhotoJob.perform_later(
      task.id,
      organisation_id: current_organisation.id,
      zip_path: zip_path,
      images_dir: images_dir,
      photo_mode: photo_mode
    )

    redirect_to bo_background_task_path(params[:org_slug], task)
  end

  # Import actions
  def import
    authorize Product, :import?
    @categories = current_organisation.categories.kept.sorted_by_full_path
    @all_skus = current_organisation.products.pluck(:sku).compact_blank +
                current_organisation.product_variants.where.not(sku: [nil, ""]).pluck(:sku)
  end

  def import_mapping
    authorize Product, :import?

    unless params[:file].present?
      redirect_to import_bo_products_path(params[:org_slug]), alert: t("bo.products.import.no_file")
      return
    end

    begin
      uploaded_file = params[:file]
      csv_content = parse_uploaded_file(uploaded_file)

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

      # Store ZIP file if provided
      if params[:zip_file].present?
        zip_path = Rails.root.join("tmp", "imports", "#{@import_key}.zip")
        File.open(zip_path, "wb") { |f| f.write(params[:zip_file].read) }
        session["import_#{@import_key}_zip"] = zip_path.to_s
      end

      # Store individual image files if provided
      if params[:image_files].present?
        images_dir = Rails.root.join("tmp", "imports", "images_#{@import_key}")
        FileUtils.mkdir_p(images_dir)
        params[:image_files].each do |image|
          File.open(images_dir.join(image.original_filename), "wb") { |f| f.write(image.read) }
        end
        session["import_#{@import_key}_images_dir"] = images_dir.to_s
      end

      # Pass through category and photo mode selections
      session["import_#{@import_key}_category_id"] = params[:category_id] if params[:category_id].present?
      session["import_#{@import_key}_photo_mode"] = params[:photo_mode] || "append"

      @importable_fields = ProductImportService.importable_fields
    rescue CSV::MalformedCSVError => e
      redirect_to import_bo_products_path(params[:org_slug]), alert: t("bo.products.import.invalid_csv", error: e.message)
    end
  end

  def import_process
    authorize Product, :import?

    import_key = params[:import_key]
    mapping = params[:mapping]&.to_unsafe_h || {}

    temp_path = Rails.root.join("tmp", "imports", "#{import_key}.csv")

    unless File.exist?(temp_path)
      redirect_to import_bo_products_path(params[:org_slug]), alert: t("bo.products.import.session_expired")
      return
    end

    csv_content = File.read(temp_path)
    col_sep = session["import_#{import_key}_col_sep"] || ","
    zip_path = session["import_#{import_key}_zip"]
    images_dir = session["import_#{import_key}_images_dir"]
    category_id = session["import_#{import_key}_category_id"]
    photo_mode = session["import_#{import_key}_photo_mode"] || "append"

    task = current_organisation.background_tasks.create!(
      member: current_member,
      task_type: "product_csv_import",
      status: :pending
    )

    ProductImportJob.perform_later(
      task.id,
      organisation_id: current_organisation.id,
      csv_content: csv_content,
      column_mapping: mapping,
      col_sep: col_sep,
      zip_path: zip_path,
      images_dir: images_dir,
      photo_mode: photo_mode,
      form_category_id: category_id
    )

    # Clean up session (temp files cleaned by job)
    File.delete(temp_path) if File.exist?(temp_path)
    session.delete("import_#{import_key}_col_sep")
    session.delete("import_#{import_key}_zip")
    session.delete("import_#{import_key}_images_dir")
    session.delete("import_#{import_key}_category_id")
    session.delete("import_#{import_key}_photo_mode")

    redirect_to bo_background_task_path(params[:org_slug], task)
  end

  def index
    @products = apply_product_filters(policy_scope(current_organisation.products).includes(:categories, :product_variants).with_attached_photos)

    # Sorting
    @sort_column = %w[name sku unit_price has_variants published].include?(params[:sort]) ? params[:sort] : "name"
    @sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
    @products = @products.order(@sort_column => @sort_direction)

    @pagy, @products = pagy(@products)

    # Load categories for filter dropdown
    @categories = current_organisation.categories.kept.sorted_by_full_path
    @suppliers = current_organisation.products.where.not(supplier: [nil, ""]).distinct.pluck(:supplier).sort_by(&:downcase)

    # Load last ERP product sync log (if ERP enabled)
    @last_product_sync = current_organisation.erp_sync_logs.for_entity('products').completed.recent.first if current_organisation.erp_configuration&.enabled?
  end

  # "Controlo de stock" tab — org-wide variant stock list with a risk status
  # (out / at-risk vs the org threshold) and the open unmet demand per variant.
  def stock_control
    authorize Product, :stock_control?
    @threshold = current_organisation.low_stock_threshold
    @stock_status = %w[out_of_stock at_risk risky].include?(params[:stock_status]) ? params[:stock_status] : nil
    @query = params[:query].to_s.strip
    @categories = current_organisation.categories.kept.sorted_by_full_path
    @suppliers = current_organisation.products.where.not(supplier: [nil, ""]).distinct.pluck(:supplier).sort_by(&:downcase)

    # real_units already joins :product, so products.* is available for
    # searching/sorting; the includes preload the option values for the label.
    scope = current_organisation.product_variants.real_units
              .includes(:product, attribute_values: :product_attribute)
    scope = case @stock_status
            when "out_of_stock" then scope.stock_out
            when "at_risk"      then scope.stock_at_risk(@threshold)
            when "risky"        then scope.stock_low_or_out(@threshold)
            else scope
            end
    if @query.present?
      scope = scope.where("products.name ILIKE :q OR product_variants.sku ILIKE :q", q: "%#{@query}%")
    end

    if params[:category_id] == "none"
      product_ids_with_category = CategoryProduct.select(:product_id)
      scope = scope.where.not(product_id: product_ids_with_category)
    elsif params[:category_id].present?
      @current_category = current_organisation.categories.kept.find_by(id: params[:category_id])
      if @current_category
        product_ids_in_category = CategoryProduct.where(category_id: @current_category.subtree_ids).select(:product_id)
        scope = scope.where(product_id: product_ids_in_category)
      end
    end

    if params[:supplier] == "none"
      scope = scope.where(products: { supplier: [nil, ""] })
    elsif params[:supplier].present?
      scope = scope.where(products: { supplier: params[:supplier] })
    end

    @sort_column    = %w[product sku stock].include?(params[:sort]) ? params[:sort] : nil
    @sort_direction = params[:direction] == "desc" ? "desc" : "asc"
    scope = scope.order(stock_control_order_sql(@sort_column, @sort_direction))

    respond_to do |format|
      format.html do
        @pagy, @variants = pagy(scope)
        @unmet_by_variant = open_unmet_shortfall_by_variant(@variants.map(&:id))
      end
      format.csv do
        variants = scope.to_a
        unmet = open_unmet_shortfall_by_variant(variants.map(&:id))
        send_data stock_control_csv(variants, unmet),
                  filename: "controlo-stock-#{current_organisation.slug}.csv",
                  type: "text/csv"
      end
    end
  end

  def catalog_selection
    authorize Product, :generate_catalog?

    @categories = current_organisation.categories.kept.roots.order(:name)

    if params[:query].present?
      scope = current_organisation.products.includes(:categories, :product_variants)
      exact_ids = scope.left_joins(:categories, :product_variants).where(
        "unaccent(products.name) ILIKE unaccent(:q) OR unaccent(products.description) ILIKE unaccent(:q) OR unaccent(products.sku) ILIKE unaccent(:q) OR unaccent(categories.name) ILIKE unaccent(:q) OR unaccent(product_variants.sku) ILIKE unaccent(:q)",
        q: "%#{params[:query]}%"
      ).select("products.id").distinct
      fuzzy_ids = scope.left_joins(:categories).where(
        "word_similarity(unaccent(:q), unaccent(products.name)) > 0.5 OR word_similarity(unaccent(:q), unaccent(categories.name)) > 0.5",
        q: params[:query]
      ).select("products.id").distinct
      scope = scope.where(id: exact_ids).or(scope.where(id: fuzzy_ids)).order(:name)
      @pagy, @products = pagy(scope, items: 30)
      @search_mode = true
    else
      @search_mode = false
    end

    render partial: "catalog_selection_content", formats: [:html]
  end

  # Design sandbox for the premium ("lookbook") catalog. Renders the premium
  # template as plain HTML (no PDF) with real products so we can iterate on the
  # visual design in-browser. Switch styles with ?style=editorial|grid|classic.
  # Not wired into GenerateCatalogJob yet — this is preview-only.
  def catalog_preview
    authorize Product, :generate_catalog?

    scope = current_organisation.products
                                .where(published: true, available: true)
                                .includes(:categories, product_variants: :product)
                                .with_attached_photos

    if params[:category_id].present?
      category = current_organisation.categories.find_by(id: params[:category_id])
      scope = scope.joins(:category_products).where(category_products: { category_id: category.subtree_ids }) if category
    end

    limit = params.fetch(:limit, 12).to_i.clamp(1, 60)
    @products = scope.order(:name).limit(limit).select(&:photo_attached?).presence ||
                scope.order(:name).limit(limit).to_a

    @style = params[:style].presence_in(%w[spread cards editorial grid classic]) || "spread"
    @orientation = params[:orient].presence_in(%w[landscape portrait]) || "landscape"
    @catalog_title = params[:title].presence || "Coleção"
    @catalog_subtitle = params[:subtitle].presence
    @client_name = params[:client].presence
    @observations = params[:observations].presence
    @show_prices = params[:show_prices] != "0"
    @show_barcode = params[:show_barcode] == "1"
    @organisation = current_organisation
    @catalog_host = request.base_url

    I18n.with_locale(@organisation.default_locale.presence || I18n.default_locale) do
      render template: "shared/catalog/premium_preview", layout: false
    end
  end

  def generate_catalog
    authorize Product, :generate_catalog?

    product_ids = params[:product_ids]&.reject(&:blank?)
    category_ids = params[:catalog_category_ids]&.reject(&:blank?)

    options = {
      "catalog_title" => params[:catalog_title],
      "show_prices" => params[:show_prices],
      "show_sku" => params[:show_sku],
      "show_barcode" => params[:show_barcode],
      "show_description" => params[:show_description],
      "show_variants" => params[:show_variants],
      "show_variant_sku" => params[:show_variant_sku],
      "show_variant_price" => params[:show_variant_price],
      "show_variant_photo" => params[:show_variant_photo],
      "catalog_layout" => params[:catalog_layout],
      "catalog_style" => params[:catalog_style],
      "premium_layout" => params[:premium_layout],
      "orientation" => params[:orientation],
      "catalog_subtitle" => params[:catalog_subtitle],
      "group_by_category" => params[:group_by_category],
      "client_name" => params[:client_name],
      "observations" => params[:observations],
      "only_available" => params[:only_available],
      "only_available_variants" => params[:only_available_variants],
      "sort_by" => params[:sort_by],
      "base_url" => request.base_url
    }

    task = current_organisation.background_tasks.create!(
      member: current_member,
      task_type: "generate_catalog",
      status: :pending
    )

    GenerateCatalogJob.perform_later(
      task.id,
      organisation_id: current_organisation.id,
      product_ids: product_ids,
      category_ids: category_ids,
      options: options
    )

    redirect_to bo_background_task_path(params[:org_slug], task)
  end

  def export_variants
    authorize Product, :export?

    task = current_organisation.background_tasks.create!(
      member: current_member,
      task_type: "export_product_variants",
      status: :pending
    )

    ExportJob.perform_later(
      task.id,
      organisation_id: current_organisation.id,
      export_class: "ProductVariant",
      export_type: "product_variants",
      columns: params[:columns],
      format: params[:format_type] || "csv",
      filter_params: filter_params_hash
    )

    redirect_to bo_background_task_path(params[:org_slug], task)
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
      save_product_attributes
      if current_organisation.deactivate_out_of_stock? && @product.default_variant
        StockRulesService.new(current_organisation).apply_to_variant(@product.default_variant)
      end
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
      save_product_attributes
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
  end

  # The picker used to render every published product in the organisation — 2766
  # of them here, each costing a photo, variant and category query, for ~15k
  # queries and 2.4 MB of HTML. It timed out (H12) and the page was unusable.
  # Now nothing is listed until this frame asks for it: same-category products
  # to begin with (the likeliest candidates, and what RelatedProductsFetcher
  # auto-fills with), then whatever the search matches.
  def related_products_search
    @results = related_products_search_scope
    # `limit:`, not `items:` — Pagy 9 renamed it, and the old name is ignored
    # without complaint, silently falling back to Pagy::DEFAULT[:limit].
    @pagy, @results = pagy(@results, limit: RELATED_PRODUCTS_PER_PAGE)

    render partial: "related_products_results", formats: [ :html ]
  end

  def update_related_products
    related_product_ids = params[:related_product_ids]&.reject(&:blank?) || []
    hide_related_products = params[:hide_related_products] == "1"

    ActiveRecord::Base.transaction do
      @product.update!(hide_related_products: hide_related_products)

      previous_ids = @product.related_product_associations.pluck(:related_product_id)
      chosen_ids = related_product_ids.map(&:to_i)

      @product.related_product_associations.destroy_all
      chosen_ids.each_with_index do |product_id, index|
        @product.related_product_associations.create!(related_product_id: product_id, position: index + 1)
      end

      mirror_related_products(chosen_ids, previous_ids)
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

  helper_method :filter_params_hash, :sort_link_params, :storefront_state

  private

  # Mirrors the catalog picker's search (Bo::ProductsController#catalog_selection):
  # accent-insensitive matching across name, SKU, description, category and
  # variant SKU, plus a fuzzy pass so a near miss or a typo still finds the
  # product. With no query we show products sharing a category with this one —
  # the likeliest candidates, and the same rule RelatedProductsFetcher uses to
  # auto-fill.
  def related_products_search_scope
    scope = current_organisation.products
                                .where(published: true)
                                .where.not(id: @product.id)
                                .includes(:categories)

    return suggestions(scope) if params[:query].blank?

    query = params[:query]
    exact_ids = scope.left_joins(:categories, :product_variants).where(
      "unaccent(products.name) ILIKE unaccent(:q) OR unaccent(products.description) ILIKE unaccent(:q) OR unaccent(products.sku) ILIKE unaccent(:q) OR unaccent(categories.name) ILIKE unaccent(:q) OR unaccent(product_variants.sku) ILIKE unaccent(:q)",
      q: "%#{query}%"
    ).select("products.id").distinct
    fuzzy_ids = scope.left_joins(:categories).where(
      "word_similarity(unaccent(:q), unaccent(products.name)) > 0.5 OR word_similarity(unaccent(:q), unaccent(categories.name)) > 0.5",
      q: query
    ).select("products.id").distinct

    scope.where(id: exact_ids).or(scope.where(id: fuzzy_ids)).order(:name)
  end

  # What to offer before the user searches. Products sharing a category are the
  # best guess, but a product with no categories — or the only one in its own —
  # would then face an empty picker reading "nothing to add" while the catalog
  # is full, so fall back to the catalog itself. @suggestion tells the view
  # which of the two it is looking at.
  def suggestions(scope)
    same_category = same_category_products(scope)

    if same_category.exists?
      @suggestion = :same_category
      same_category
    else
      @suggestion = :all
      scope.order(:name)
    end
  end

  # Relationships are mutual, so every link is kept in both directions: picking
  # B on A's page gives B a link back to A, and dropping it from either side
  # drops both. Ordering on the other side is not ours to decide, so a new
  # mirror simply goes to the end of that product's list.
  def mirror_related_products(chosen_ids, previous_ids)
    chosen_ids.each do |other_id|
      RelatedProduct.find_or_create_by!(product_id: other_id, related_product_id: @product.id)
    end

    (previous_ids - chosen_ids).each do |dropped_id|
      RelatedProduct.where(product_id: dropped_id, related_product_id: @product.id).destroy_all
    end
  end

  def same_category_products(scope)
    category_ids = @product.categories.pluck(:id)
    category_ids << @product.category_id if @product.category_id.present?
    return scope.none if category_ids.empty?

    scope.where(id: CategoryProduct.where(category_id: category_ids).select(:product_id)).order(:name)
  end

  # Total open unmet demand (Quis − Levou) per variant — the Faltas cross-link
  # for the stock list. Returns { variant_id => outstanding_shortfall }.
  def open_unmet_shortfall_by_variant(variant_ids)
    return {} if variant_ids.blank?

    current_organisation.unmet_demands.open
      .where(product_variant_id: variant_ids)
      .group(:product_variant_id)
      .sum(Arel.sql("requested_quantity - fulfilled_quantity"))
  end

  # ORDER clause for the stock-control list. @sort_direction is validated to
  # asc/desc so the interpolation is safe; default floats risk to the top.
  def stock_control_order_sql(column, direction)
    dir = direction == "desc" ? "DESC" : "ASC"
    case column
    when "product" then Arel.sql("products.name #{dir}")
    when "sku"     then Arel.sql("product_variants.sku #{dir} NULLS LAST")
    when "stock"   then Arel.sql("product_variants.stock_quantity #{dir} NULLS LAST")
    else Arel.sql("(product_variants.track_stock IS TRUE) DESC, product_variants.stock_quantity ASC NULLS LAST")
    end
  end

  def stock_control_csv(variants, unmet)
    CSV.generate(headers: true) do |csv|
      csv << ["Produto", "Variante", "SKU", "Fornecedor", "Stock", "Status", "Em falta"]
      variants.each do |v|
        status = v.stock_control_status(@threshold)
        csv << [
          v.product&.name,
          v.option_values_string,
          v.sku,
          v.product&.supplier,
          v.track_stock? ? v.stock_quantity.to_i : "∞",
          I18n.t("bo.products.stock_control.status.#{status}"),
          unmet[v.id].to_i
        ]
      end
    end
  end

  def exportable_class
    Product
  end

  def exportable_base_scope
    policy_scope(current_organisation.products).includes(:categories)
  end

  def apply_export_filters(scope)
    apply_product_filters(scope)
  end

  def filter_params_hash
    { query: params[:query], category_id: params[:category_id], product_type: params[:product_type],
      price_status: params[:price_status], status: params[:status], storefront: params[:storefront],
      supplier: params[:supplier], sort: params[:sort], direction: params[:direction], page: params[:page] }.compact_blank
  end

  def sort_link_params(column)
    direction = (@sort_column == column && @sort_direction == "asc") ? "desc" : "asc"
    filter_params_hash.except(:page).merge(sort: column, direction: direction)
  end

  def storefront_state(product)
    return "hidden" unless product.published?
    return "purchasable" if product.purchasable?
    # Published but not purchasable — check if any variant is visible
    variants = product.variable? ? product.product_variants.select { |v| !v.is_default? && v.published? } : product.product_variants.select(&:published?)
    has_visible = variants.any? { |v| v.available? || v.effective_stock_policy != 'hide' }
    has_visible ? "no_stock" : "hidden"
  end

  def apply_product_filters(scope)
    if params[:query].present?
      exact_ids = scope.left_joins(:categories, :product_variants).where(
        "unaccent(products.name) ILIKE unaccent(:q) OR unaccent(products.sku) ILIKE unaccent(:q) OR unaccent(products.description) ILIKE unaccent(:q) OR unaccent(categories.name) ILIKE unaccent(:q) OR unaccent(product_variants.sku) ILIKE unaccent(:q)",
        q: "%#{params[:query]}%"
      ).select("products.id").distinct
      fuzzy_ids = scope.left_joins(:categories).where(
        "word_similarity(unaccent(:q), unaccent(products.name)) > 0.5 OR word_similarity(unaccent(:q), unaccent(categories.name)) > 0.5",
        q: params[:query]
      ).select("products.id").distinct
      scope = scope.where(id: exact_ids).or(scope.where(id: fuzzy_ids))
    end

    if params[:category_id] == "none"
      product_ids_with_category = CategoryProduct.select(:product_id)
      scope = scope.where.not(id: product_ids_with_category)
    elsif params[:category_id].present?
      category = current_organisation.categories.kept.find_by(id: params[:category_id])
      if category
        @current_category = category
        all_category_ids = category.subtree_ids
        product_ids_in_category = CategoryProduct.where(category_id: all_category_ids).select(:product_id)
        scope = scope.where(id: product_ids_in_category)
      end
    end

    if params[:supplier] == "none"
      scope = scope.where(supplier: [nil, ""])
    elsif params[:supplier].present?
      scope = scope.where(supplier: params[:supplier])
    end

    if params[:product_type].present?
      case params[:product_type]
      when "simple" then scope = scope.simple
      when "variable" then scope = scope.variable
      end
    end

    case params[:price_status]
    when "on_request" then scope = scope.where(price_on_request: true)
    when "zero_price" then scope = scope.where(price_on_request: false, unit_price: [nil, 0])
    when "has_price" then scope = scope.where(price_on_request: false).where("unit_price > 0")
    end

    case params[:status]
    when "published"
      scope = scope.where(published: true).where.not(
        id: Product.joins(:product_variants).where(has_variants: true, product_variants: { published: false }).select(:id)
      )
    when "unpublished"
      scope = scope.where(published: false)
    when "partial"
      scope = scope.where(has_variants: true, published: true).where(
        id: Product.joins(:product_variants).where(has_variants: true, product_variants: { published: false }).select(:id)
      )
    end

    if params[:storefront].present?
      # Compute storefront state in Ruby (depends on effective_stock_policy which resolves inherit)
      all_products = scope.includes(:product_variants).to_a
      filtered_ids = all_products.select { |p| storefront_state(p) == params[:storefront] }.map(&:id)
      scope = scope.where(id: filtered_ids)
    end

    scope
  end

  def set_product
    @product = current_organisation.products.includes(:product_variants).find(params[:id])
    authorize @product
  end

  def product_params
    params.require(:product).permit(:name, :slug, :sku, :description, :rich_description, :price, :unit_description, :min_quantity, :min_quantity_type, :min_quantity_scope, :published, :price_on_request, :hide_sku_on_card, :category_id, :add_to_cart_mode, :supplier, category_ids: [], photos: [])
  end

  def parse_uploaded_file(uploaded_file)
    filename = uploaded_file.original_filename.downcase

    if filename.end_with?(".xlsx", ".xls")
      convert_excel_to_csv(uploaded_file)
    else
      content = uploaded_file.read.force_encoding("UTF-8")
      content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    end
  end

  def convert_excel_to_csv(uploaded_file)
    require "roo" # gem is require:false; only paid for during XLSX uploads
    spreadsheet = Roo::Spreadsheet.open(uploaded_file.path || uploaded_file.tempfile.path)
    sheet = spreadsheet.sheet(0)

    CSV.generate do |csv|
      sheet.each_row_streaming(pad_cells: true) do |row|
        csv << row.map { |cell| cell&.value.to_s }
      end
    end
  end

  def detect_csv_delimiter(content)
    sample = content[0, 1024] || content
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

  def load_attributes_for_form
    @all_attributes = {}
    @current_attribute_value_ids = []

    current_organisation.product_attributes.kept.active.by_position.each do |attribute|
      values = attribute.product_attribute_values.where(active: true).naturally_sorted
      @all_attributes[attribute] = values
    end

    if @product&.persisted? && !@product.has_variants?
      @current_attribute_value_ids = @product.default_variant&.attribute_values&.pluck(:id) || []
    end
  end

  def save_product_attributes
    return if @product.has_variants?

    variant = @product.default_variant
    return unless variant

    ids = params.dig(:product, :attribute_value_ids)&.reject(&:blank?)&.map(&:to_i) || []

    variant.variant_attribute_values.destroy_all
    ids.each do |value_id|
      variant.variant_attribute_values.create!(product_attribute_value_id: value_id)
    end

    sync_product_attribute_associations(ids)
  end

  def sync_product_attribute_associations(value_ids)
    if value_ids.blank?
      @product.product_product_attributes.destroy_all
      @product.product_available_values.destroy_all
      return
    end

    values = ProductAttributeValue.where(id: value_ids)
    attribute_ids = values.pluck(:product_attribute_id).uniq

    @product.product_product_attributes.where.not(product_attribute_id: attribute_ids).destroy_all
    attribute_ids.each_with_index do |attr_id, index|
      @product.product_product_attributes.find_or_create_by!(product_attribute_id: attr_id) do |ppa|
        ppa.position = index + 1
      end
    end

    @product.product_available_values.where.not(product_attribute_value_id: value_ids).destroy_all
    value_ids.each do |val_id|
      @product.product_available_values.find_or_create_by!(product_attribute_value_id: val_id)
    end
  end
end
