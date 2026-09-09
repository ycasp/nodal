class GenerateCatalogJob < ApplicationJob
  include Trackable

  queue_as :default

  # Grover/Chrome is memory-heavy. On the current (memory-tight) dyno, two
  # catalog renders at once exhaust memory (R14 -> R15 -> crash). Serialize so
  # only ONE catalog is generated at a time across the whole app; the rest wait.
  # `duration` releases the slot if a job dies without cleaning up, so the queue
  # never deadlocks.
  limits_concurrency to: 1, key: ->(*_args) { "catalog_generation" }, duration: 15.minutes

  def perform(task_id, organisation_id:, product_ids: nil, category_ids: nil, options: {})
    find_task(task_id)
    organisation = Organisation.find(organisation_id)

    # Query products
    products = organisation.products
      .includes(:categories, :product_variants, product_variants: :attribute_values)
      .with_attached_photos

    if product_ids.present?
      products = products.where(id: product_ids)
    elsif category_ids.present?
      # Expand to the full subtree so products in nested subcategories are included
      all_category_ids = organisation.categories.where(id: category_ids)
                                     .flat_map(&:subtree_ids).uniq
      product_ids_from_cats = CategoryProduct.where(category_id: all_category_ids).select(:product_id)
      products = products.where(id: product_ids_from_cats)
    end

    if options["only_available"] != "0"
      products = products.where(published: true, available: true)
    end

    case options["sort_by"]
    when "price" then products = products.order(:unit_price)
    else products = products.order(:name)
    end

    # Generate PDF via chunked service
    service = CatalogPdfService.new(
      products: products,
      organisation: organisation,
      options: options
    )

    pdf = service.generate do |progress, total|
      update_progress(progress, total)
    end

    catalog_title = options["catalog_title"].presence || organisation.name
    filename = "#{catalog_title.parameterize}_#{Date.today.iso8601}.pdf"

    @background_task.file.attach(
      io: StringIO.new(pdf),
      filename: filename,
      content_type: "application/pdf",
      service_name: "local"
    )

    save_result({ filename: filename, product_count: products.size })
  end
end
