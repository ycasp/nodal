require "base64"

class CatalogPdfService
  CHUNK_SIZE = 20
  IMAGE_TIMEOUT = 10
  GROVER_TIMEOUT = 60_000 # 60 seconds per chunk
  MAX_RETRIES = 2

  def initialize(products:, organisation:, options: {})
    @products = products.to_a
    @organisation = organisation
    @options = options
    @renderer = ApplicationController.renderer.new
    @catalog_host = options["base_url"] || "http://localhost:3000"
    @show_variants = options["show_variants"] == "1"
    @show_variant_photo = options["show_variant_photo"] == "1"
    @only_available_variants = options["only_available_variants"] != "0"
  end

  def generate(&progress_callback)
    return generate_premium(&progress_callback) if premium?

    chunks = @products.each_slice(CHUNK_SIZE).to_a
    total_steps = chunks.size + 2 # cover + chunks + contact
    progress_callback&.call(0, total_steps)

    # Step 1: Cover page PDF
    cover_pdf = generate_cover_pdf
    progress_callback&.call(1, total_steps)

    # Step 2: Product chunks
    chunk_pdfs = chunks.each_with_index.map do |chunk, index|
      pdf = generate_chunk_pdf(chunk, index, chunks.size)
      progress_callback&.call(index + 2, total_steps)
      pdf
    end

    # Step 3: Contact page PDF
    contact_pdf = generate_contact_pdf
    progress_callback&.call(total_steps, total_steps)

    # Merge all PDFs
    merge_pdfs([cover_pdf] + chunk_pdfs + [contact_pdf].compact)
  end

  private

  def premium?
    @options["catalog_style"].to_s == "premium"
  end

  # How many product PAGES to render per Grover call. Each chunk builds only its
  # own images (base64) and frees them before the next, so headless Chrome never
  # holds the whole catalog at once — this is what keeps the functional catalog
  # inside the dyno's memory, and the premium one now matches it.
  PREMIUM_PAGES_PER_CHUNK = 4

  # Premium ("lookbook") catalog, rendered in memory-bounded chunks:
  # cover -> product pages in chunks (images freed between chunks) -> back cover,
  # then merged. Reuses shared/catalog/premium_preview via @pdf_section.
  def generate_premium(&progress_callback)
    orientation = @options["orientation"] == "portrait" ? "portrait" : "landscape"
    style = @options["premium_layout"] == "spread" ? "spread" : "cards"
    per_page = premium_per_page(style, orientation)
    chunks = @products.each_slice(per_page * PREMIUM_PAGES_PER_CHUNK).to_a

    logo_data = download_logo
    total_steps = chunks.size + 2
    progress_callback&.call(0, total_steps)

    pdfs = []
    pdfs << render_premium_section("cover", [], style, orientation, {}, logo_data, 0)
    progress_callback&.call(1, total_steps)

    page_offset = 0
    chunks.each_with_index do |chunk, index|
      image_map = build_premium_image_map(chunk)
      pdfs << render_premium_section("pages", chunk, style, orientation, image_map, logo_data, page_offset)
      image_map.clear
      page_offset += style == "spread" ? chunk.size : (chunk.size.to_f / per_page).ceil
      progress_callback&.call(index + 2, total_steps)
    end

    if @options["observations"].present? || @organisation.has_contact_info?
      pdfs << render_premium_section("back", [], style, orientation, {}, logo_data, 0)
    end
    progress_callback&.call(total_steps, total_steps)

    merge_pdfs(pdfs.compact)
  end

  def premium_per_page(style, orientation)
    return 1 if style == "spread"
    orientation == "portrait" ? 4 : 3
  end

  # Renders one section of the premium catalog ("cover" | "pages" | "back") to a
  # PDF binary. Only "pages" receives products + an image_map.
  def render_premium_section(section, products, style, orientation, image_map, logo_data, page_offset)
    html = I18n.with_locale(@organisation.default_locale.presence || I18n.locale) do
      @renderer.render(
        template: "shared/catalog/premium_preview",
        layout: false,
        assigns: {
          products: products,
          style: style,
          orientation: orientation,
          pdf_mode: true,
          pdf_section: section,
          page_offset: page_offset,
          catalog_title: catalog_title,
          catalog_subtitle: @options["catalog_subtitle"].presence,
          client_name: @options["client_name"].presence,
          observations: @options["observations"].presence,
          show_prices: @options["show_prices"] != "0",
          show_sku: @options.fetch("show_sku", "1") == "1",
          show_barcode: @options["show_barcode"] == "1",
          organisation: @organisation,
          catalog_host: @catalog_host,
          image_map: image_map,
          logo_data: logo_data
        }
      )
    end
    render_premium_pdf_with_retry(html, orientation)
  end

  def build_premium_image_map(products)
    map = {}
    products.each do |product|
      att = product.photo_attached? ? product.photo : product.display_photo
      next unless att
      data = download_image(att, limit: [800, 800])
      map[product.id] = data if data
    end
    map
  end

  def render_premium_pdf_with_retry(html, orientation)
    retries = 0
    begin
      Grover.new(html, **premium_grover_options(orientation)).to_pdf
    rescue StandardError => e
      retries += 1
      if retries <= MAX_RETRIES
        Rails.logger.warn("[CatalogPDF] Premium render failed (attempt #{retries}): #{e.message}")
        sleep(retries * 2)
        retry
      end
      raise
    end
  end

  def premium_grover_options(orientation)
    {
      format: "A4",
      landscape: orientation != "portrait",
      print_background: true,
      prefer_css_page_size: true,
      margin: { top: "0", bottom: "0", left: "0", right: "0" },
      wait_until: "networkidle0",
      timeout: GROVER_TIMEOUT,
      launch_args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu"
      ],
      executable_path: chrome_path
    }.compact
  end

  def generate_cover_pdf
    logo_data = download_logo
    html = @renderer.render(
      template: "shared/catalog/cover_pdf",
      layout: false,
      assigns: {
        organisation: @organisation,
        catalog_title: catalog_title,
        product_count: @products.size,
        client_name: @options["client_name"].presence,
        logo_data: logo_data,
        catalog_host: @catalog_host
      }
    )
    render_pdf(html)
  end

  def generate_chunk_pdf(products_chunk, chunk_index, total_chunks)
    image_map = build_image_map(products_chunk)

    # Group by category if needed
    grouped = if @options["group_by_category"] == "1"
      products_chunk.group_by { |p| p.primary_category&.name || I18n.t("bo.catalog.pdf.uncategorized") }.sort_by(&:first)
    else
      nil
    end

    html = @renderer.render(
      template: "shared/catalog/chunk_pdf",
      layout: false,
      assigns: chunk_assigns(products_chunk, image_map, grouped)
    )

    # Release image data for GC
    image_map.clear

    render_pdf_with_retry(html)
  end

  def generate_contact_pdf
    observations = @options["observations"].presence
    return nil unless @organisation.has_contact_info? || observations

    html = @renderer.render(
      template: "shared/catalog/contact_pdf",
      layout: false,
      assigns: {
        organisation: @organisation,
        catalog_title: catalog_title,
        observations: observations
      }
    )
    render_pdf(html)
  end

  def build_image_map(products)
    map = {}
    products.each do |product|
      map[product.id] = download_image(product.photo) if product.photo_attached?

      next unless @show_variants && product.has_variants?

      variants = product.product_variants.reject(&:is_default?).select(&:published?)
      variants = variants.select(&:available?) if @only_available_variants
      variants.each do |variant|
        next unless @show_variant_photo && variant.photo.attached?
        map["variant_#{variant.id}"] = download_image(variant.photo, small: true)
      end
    end
    map
  end

  def download_image(attachment, small: false, limit: nil)
    limit ||= small ? [100, 100] : [400, 400]
    variant = attachment.variant(resize_to_limit: limit)
    variant.processed
    data = variant.download
    content_type = attachment.blob.content_type || "image/jpeg"
    "data:#{content_type};base64,#{Base64.strict_encode64(data)}"
  rescue StandardError => e
    Rails.logger.warn("[CatalogPDF] Failed to download image: #{e.message}")
    nil
  end

  def download_logo
    return nil unless @organisation.logo.attached?
    download_image(@organisation.logo)
  end

  def render_pdf(html)
    Grover.new(html, **grover_options).to_pdf
  end

  def render_pdf_with_retry(html)
    retries = 0
    begin
      render_pdf(html)
    rescue StandardError => e
      retries += 1
      if retries <= MAX_RETRIES
        Rails.logger.warn("[CatalogPDF] Chunk render failed (attempt #{retries}): #{e.message}")
        sleep(retries * 2)
        retry
      end
      raise
    end
  end

  def merge_pdfs(pdf_binaries)
    require "combine_pdf" # gem is require:false; only loaded during catalog generation
    combined = CombinePDF.new
    pdf_binaries.each do |pdf_data|
      next if pdf_data.nil?
      combined << CombinePDF.parse(pdf_data)
    end
    combined.to_pdf
  end

  def grover_options
    {
      format: "A4",
      print_background: true,
      margin: { top: "20mm", bottom: "20mm", left: "15mm", right: "15mm" },
      wait_until: "domcontentloaded",
      timeout: GROVER_TIMEOUT,
      launch_args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu"
      ],
      executable_path: chrome_path
    }.compact
  end

  def chrome_path
    if Rails.env.development?
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    else
      ENV["GOOGLE_CHROME_BIN"] || ENV["PUPPETEER_EXECUTABLE_PATH"] || ENV["GOOGLE_CHROME_SHIM"]
    end
  end

  def catalog_title
    @options["catalog_title"].presence || @organisation.name
  end

  def chunk_assigns(products_chunk, image_map, grouped)
    card_attributes, card_attribute_data = card_attributes_for(products_chunk)
    {
      products: products_chunk,
      image_map: image_map,
      catalog_title: catalog_title,
      show_prices: @options["show_prices"] != "0",
      show_sku: @options["show_sku"] == "1",
      show_description: @options["show_description"] == "1",
      show_variants: @show_variants,
      show_variant_sku: @options["show_variant_sku"] == "1",
      show_variant_price: @options["show_variant_price"] == "1",
      show_variant_photo: @show_variant_photo,
      show_barcode: @options["show_barcode"] == "1",
      only_available_variants: @only_available_variants,
      card_attributes: card_attributes,
      card_attribute_data: card_attribute_data,
      layout: @options["catalog_layout"] == "list" ? "list" : "grid",
      group_by_category: @options["group_by_category"] == "1",
      grouped: grouped,
      organisation: @organisation,
      catalog_host: @catalog_host
    }
  end

  # Card attributes for SIMPLE products in this chunk, mirroring the storefront
  # card display (attributes flagged show_on_card, read from the default variant).
  # Variable products already surface their attributes through the variant list.
  # Returns [ordered_attributes, { product_id => { attribute => [values] } }].
  def card_attributes_for(products_chunk)
    card_attributes = @organisation.product_attributes.where(show_on_card: true).by_position.to_a
    simple_ids = products_chunk.reject(&:has_variants?).map(&:id)
    return [card_attributes, {}] if card_attributes.empty? || simple_ids.empty?

    pairs = VariantAttributeValue
      .joins(product_variant: :product)
      .joins(:product_attribute_value)
      .where(products: { id: simple_ids })
      .where(product_variants: { is_default: true, published: true, available: true })
      .where(product_attribute_values: { product_attribute_id: card_attributes.map(&:id) })
      .pluck(:product_id, :product_attribute_value_id)

    values_by_id = ProductAttributeValue
      .where(id: pairs.map(&:last).uniq)
      .includes(:product_attribute)
      .index_by(&:id)

    data = pairs.group_by(&:first).transform_values do |rows|
      rows.map { |(_pid, vid)| values_by_id[vid] }.compact.uniq.group_by(&:product_attribute)
    end

    [card_attributes, data]
  end
end
