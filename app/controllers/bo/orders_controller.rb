class Bo::OrdersController < Bo::BaseController
  include Exportable

  before_action :set_order, only: [:show, :edit, :update, :destroy, :apply_discount, :remove_discount, :set_shipping, :download_pdf, :retry_push]

  def index
    @orders = apply_order_filters(policy_scope(current_organisation.orders.placed).includes(:customer, :customer_user, :placed_by, :order_items))

    sort_direction = %w[asc desc].include?(params[:sort_dir]) ? params[:sort_dir] : "desc"
    @orders = @orders.order(Arel.sql("COALESCE(orders.placed_at, orders.created_at) #{sort_direction}"))
    @pagy, @orders = pagy(@orders)

    # Filter dropdown of customers: pure reps see only their carteira; everyone
    # else sees the full org list (matches the underlying order scope).
    @customers =
      if pure_sales_rep?
        current_org_member.assigned_customers.order(:company_name)
      else
        current_organisation.customers.order(:company_name)
      end
  end

  def show
    # Pure reps viewing an order should NOT clear the BO unreviewed badge —
    # the admin team still needs to know there's a new order to process.
    @order.mark_as_reviewed! unless pure_sales_rep?
  end

  def edit
  end

  VARIANT_SEARCH_LIMIT = 30

  # Type-ahead for picking an order line. Searches variants, not products: the
  # SKU lives on the variant, and it is the only thing that tells apart the 45
  # products called "Moldura Criança" in this catalog. Unpublished items are
  # included on purpose — the back office has to be able to put anything on an
  # order.
  def variant_search
    authorize Order, :variant_search?

    render json: variant_search_scope.map { |variant| variant_option(variant) }
  end

  # What this line should start at: the variant's price, and the discount the
  # shop would give this customer. Both land in editable fields — the back
  # office can override either — so this is a starting point, not a verdict.
  def variant_pricing
    authorize Order, :variant_pricing?

    variant = current_organisation.product_variants.find(params[:variant_id])
    customer = current_organisation.customers.find_by(id: params[:customer_id])
    quantity = params[:quantity].presence&.to_i || 1

    discount = DiscountCalculator.new(
      product: variant.product,
      customer: customer,
      quantity: quantity,
      variant: variant
    ).effective_discount[:percentage] || 0

    render json: {
      product_id: variant.product_id,
      unit_price: ((variant.unit_price_cents || variant.product.unit_price).to_i / 100.0).round(2),
      discount_percentage: discount
    }
  end

  def new
    @order = Order.new
    @customers = Customer.where(organisation: @current_organisation)
    authorize @order
  end

  def create
    @order = Order.new(order_params)
    @order.organisation = @current_organisation
    @order.placed_at = Time.current
    authorize @order

    if @order.save
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id), notice: "Order created successfully."
    else
      @customers = Customer.where(organisation: @current_organisation)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @order.update(order_params)
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id, **filter_params_hash), notice: "Order updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @order.destroy
    redirect_to bo_orders_path(org_slug: @current_organisation.slug, **filter_params_hash), notice: "Order deleted successfully."
  end

  def apply_discount
    if @order.update(order_discount_params.merge(applied_by: current_member))
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id),
                  notice: "Discount applied successfully."
    else
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id),
                  alert: "Failed to apply discount: #{@order.errors.full_messages.join(', ')}"
    end
  end

  def remove_discount
    @order.update(discount_type: nil, discount_value: nil, discount_reason: nil, applied_by: nil)
    redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id),
                notice: "Discount removed."
  end

  # Prices the shipping on an order that was placed while the real cost was
  # still unknown. Clearing the field puts the order back into "to be
  # calculated" so a wrong number is never stuck on the order.
  def set_shipping
    authorize @order
    amount = params.dig(:order, :shipping_amount).presence

    if amount.nil?
      @order.update!(shipping_amount: nil, shipping_pending: true)
      notice = t('bo.orders.shipping.cleared', default: "Shipping cost cleared.")
    else
      @order.update!(shipping_amount: amount)
      notice = t('bo.orders.shipping.saved', default: "Shipping cost saved.")
    end

    redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id), notice: notice
  rescue ActiveRecord::RecordInvalid => e
    redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id),
                alert: e.record.errors.full_messages.to_sentence
  end

  def download_pdf
    html = render_to_string(template: "shared/orders/pdf", layout: false)
    pdf = Grover.new(html).to_pdf

    send_data pdf,
      filename: "#{@order.order_number}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end

  def retry_push
    authorize @order
    # A person clicking this is saying "I fixed it, try again", so the attempt
    # budget starts over — without that the push refused itself immediately and
    # left the order sitting at `pending`, with the retry button gone because
    # it only shows for `failed`. Clearing last_pushed_at skips the cooldown.
    @order.update!(push_status: "pending", push_attempts: 0, sync_error: nil, last_pushed_at: nil)
    OrderPushJob.perform_later(@order.id)
    redirect_to bo_orders_path(org_slug: @current_organisation.slug, **filter_params_hash),
                notice: t('bo.orders.push_retry.queued', number: @order.order_number, default: "Push queued for order %{number}")
  end

  def export_items
    authorize Order, :export?

    task = current_organisation.background_tasks.create!(
      member: current_member,
      task_type: "export_order_items",
      status: :pending
    )

    ExportJob.perform_later(
      task.id,
      organisation_id: current_organisation.id,
      export_class: "OrderItem",
      export_type: "order_items",
      columns: params[:columns],
      format: params[:format_type] || "csv",
      filter_params: filter_params_hash
    )

    redirect_to bo_background_task_path(params[:org_slug], task)
  end

  helper_method :filter_params_hash

  private

  # Everything the catalog has is offered, not only what the shop would sell: the
  # back office has to be able to put a restock, or something still unpublished,
  # on an order. But never blindly — each result carries its stock and whether
  # the shop can sell it, so an unusual choice is a choice and not an accident.
  def variant_option(variant)
    warnings = []
    warnings << t("bo.orders.form.picker_out_of_stock") if variant.track_stock? && variant.stock_quantity.to_i <= 0
    warnings << t("bo.orders.form.picker_unpublished") unless variant.published? && variant.product.published?

    {
      value: variant.id,
      text: variant.picker_label,
      sku: variant.sku.to_s,
      stock: variant.track_stock? ? t("bo.orders.form.picker_stock", count: variant.stock_quantity.to_i) : t("bo.orders.form.picker_no_stock_control"),
      warning: warnings.join(" · ").presence
    }
  end

  # Variants, not products, and never the placeholder base variant of a variable
  # product — that one is not a sellable unit. Matching is accent-insensitive on
  # both the SKU and the product name, so "coracao" finds "Coração".
  def variant_search_scope
    scope = current_organisation.product_variants
                                .real_units
                                .includes(:product, attribute_values: :product_attribute)

    query = params[:query].to_s.strip
    return scope.none if query.blank?

    scope.joins(:product).where(
      "unaccent(product_variants.sku) ILIKE unaccent(:q) OR unaccent(products.name) ILIKE unaccent(:q)",
      q: "%#{query}%"
    ).order("products.name").limit(VARIANT_SEARCH_LIMIT)
  end

  def exportable_class
    Order
  end

  def exportable_base_scope
    policy_scope(current_organisation.orders.placed).includes(:customer, :customer_user, :placed_by, :order_items)
  end

  def apply_export_filters(scope)
    apply_order_filters(scope)
  end

  def filter_params_hash
    { search: params[:search], status: params[:status],
      payment_status: params[:payment_status], customer_id: params[:customer_id],
      date_from: params[:date_from], date_to: params[:date_to],
      push_status: params[:push_status],
      sort_dir: params[:sort_dir], page: params[:page] }.compact_blank
  end

  def apply_order_filters(scope)
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      scope = scope.joins(:customer).where(
        "unaccent(orders.order_number) ILIKE unaccent(:search) OR unaccent(customers.company_name) ILIKE unaccent(:search) OR unaccent(customers.contact_name) ILIKE unaccent(:search)",
        search: search_term
      )
    end

    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(payment_status: params[:payment_status]) if params[:payment_status].present?
    scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    scope = scope.where(push_status: params[:push_status]) if params[:push_status].present? && Order::PUSH_STATUSES.include?(params[:push_status])

    if params[:date_from].present?
      scope = scope.where("COALESCE(orders.placed_at, orders.created_at) >= ?", params[:date_from].to_date.beginning_of_day)
    end

    if params[:date_to].present?
      scope = scope.where("COALESCE(orders.placed_at, orders.created_at) <= ?", params[:date_to].to_date.end_of_day)
    end

    scope
  end

  def set_order
    @order = Order.find(params[:id])
    authorize @order
  end

  def order_params
    params.require(:order).permit(
      :customer_id, :status, :payment_status, :receive_on, :notes,
      order_items_attributes: [ :id, :product_id, :product_variant_id, :quantity, :price, :discount_percent, :discount_percentage, :note, :_destroy ]
    )
  end

  def order_discount_params
    params.require(:order).permit(:discount_type, :discount_value, :discount_reason)
  end
end
