class ExportJob < ApplicationJob
  include Trackable

  queue_as :default

  def perform(task_id, organisation_id:, export_class:, export_type:, columns:, format: "csv", filter_params: {})
    find_task(task_id)
    organisation = Organisation.find(organisation_id)

    update_progress(0, 2)

    # Step 1: Query and filter records
    klass = export_class.constantize
    export_columns = klass.exportable_columns_for(columns)

    records = build_scope(organisation, export_type, klass, filter_params)
    update_progress(1)

    # Step 2: Generate export
    result = ExportService.new(records: records, columns: export_columns, format: format).call

    extension = format == "xlsx" ? "xlsx" : "csv"
    filename = "#{klass.model_name.plural}_#{Date.today.iso8601}.#{extension}"

    @background_task.file.attach(
      io: StringIO.new(result[:data]),
      filename: filename,
      content_type: result[:content_type]
    )

    save_result({ filename: filename, record_count: records.size })
    update_progress(2)
  end

  private

  def build_scope(organisation, export_type, klass, filter_params)
    params_obj = ActionController::Parameters.new(filter_params).permit!

    case export_type
    when "products"
      scope = organisation.products.includes(:categories)
      apply_product_filters(scope, params_obj)
    when "product_variants"
      product_ids = apply_product_filters(organisation.products, params_obj).select(:id)
      ProductVariant.where(product_id: product_ids)
                    .includes(:product, :attribute_values, product: :categories)
                    .order(:product_id, :position)
    when "orders"
      scope = organisation.orders.placed.includes(:customer, :order_items)
      apply_order_filters(scope, params_obj)
    when "order_items"
      order_ids = apply_order_filters(organisation.orders.placed, params_obj).select(:id)
      OrderItem.where(order_id: order_ids).includes(:order, :product, :product_variant, order: :customer)
    when "customers"
      scope = organisation.customers.includes(:customer_category)
      apply_customer_filters(scope, params_obj)
    else
      klass.where(organisation: organisation)
    end
  end

  def apply_product_filters(scope, params)
    scope = scope.where("products.name ILIKE :q OR products.sku ILIKE :q", q: "%#{params[:query]}%") if params[:query].present?
    scope = scope.joins(:categories).where(categories: { id: params[:category_id] }) if params[:category_id].present?
    scope = scope.where(has_variants: true) if params[:product_type] == "variable"
    scope = scope.where(has_variants: false) if params[:product_type] == "simple"
    scope = scope.where(published: true) if params[:status] == "active"
    scope = scope.where(published: false) if params[:status] == "inactive"
    scope
  end

  def apply_order_filters(scope, params)
    scope = scope.joins(:customer).where("customers.name ILIKE :q OR customers.company_name ILIKE :q OR orders.order_number ILIKE :q", q: "%#{params[:search]}%") if params[:search].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(payment_status: params[:payment_status]) if params[:payment_status].present?
    scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    scope = scope.where("orders.placed_at >= ?", params[:start_date]) if params[:start_date].present?
    scope = scope.where("orders.placed_at <= ?", params[:end_date]) if params[:end_date].present?
    scope
  end

  def apply_customer_filters(scope, params)
    scope = scope.where("customers.name ILIKE :q OR customers.email ILIKE :q OR customers.company_name ILIKE :q", q: "%#{params[:query]}%") if params[:query].present?
    scope = scope.where(active: true) if params[:status] == "active"
    scope = scope.where(active: false) if params[:status] == "inactive"
    scope = scope.joins(:customer_category).where(customer_categories: { id: params[:category] }) if params[:category].present?
    scope
  end
end
