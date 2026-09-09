class Bo::CustomersController < Bo::BaseController
  include Exportable

  before_action :set_and_authorize_customer, only: [:show, :edit, :update, :destroy, :logins_modal]

  def index
    @tab = params[:tab] || 'customers'
    @customer_categories = current_organisation.customer_categories.ordered

    # Always call policy_scope to satisfy Pundit's verify_policy_scoped
    load_customers

    if @tab == 'customers'
      @invitation_kpis = Dashboard::Metrics
        .customer_health(organisation: current_organisation)
        .slice(:total_customers, :active_users, :pending_users, :stale_pending_users, :uninvited_users,
               :no_email_users)
    end
  end

  def show
    placed_orders = @customer.orders.placed.order(placed_at: :desc).includes(:order_items, :organisation)
    @total_orders = placed_orders.count
    currency = current_organisation.currency
    if @total_orders > 0
      total_cents = placed_orders.sum { |o| o.grand_total.cents }
      @total_spent = Money.new(total_cents, currency)
      @average_order_value = Money.new(total_cents / @total_orders, currency)
    else
      @total_spent = Money.new(0, currency)
      @average_order_value = Money.new(0, currency)
    end
    @last_order = placed_orders.first
    @recent_orders = placed_orders.limit(5)
    @open_cart = @customer.orders.draft.includes(:order_items).first

    @avg_order_interval_days = if @total_orders >= 2
      span = @last_order.placed_at - placed_orders.last.placed_at
      (span / (@total_orders - 1) / 1.day).round
    end
  end

  def new
    @customer = Customer.new
    @customer.build_billing_address_with_archived(address_type: "billing")
    @customer.shipping_addresses_with_archived.build(address_type: "shipping")
    @customer_categories = current_organisation.customer_categories.ordered
    authorize @customer
  end

  def create
    @customer = Customer.new(customer_params)
    @customer.organisation = current_organisation
    @customer.created_by_member = current_org_member
    # Pure reps don't see the "active" toggle (it's locked to org default), so
    # the field is stripped from params — backfill the boolean here to satisfy
    # the model validation (inclusion: in [true, false]).
    @customer.active = true if @customer.active.nil?
    authorize @customer
    if @customer.save
      # Sales reps creating a customer auto-claim it for their carteira.
      # Owners/admins who are also reps can self-assign explicitly via the
      # assignment UX — we don't auto-grab on their behalf here, since they
      # may be creating on behalf of a different rep.
      if pure_sales_rep?
        CustomerAssignment.create!(org_member: current_org_member, customer: @customer)
      end
      redirect_to bo_customer_path(params[:org_slug], @customer), notice: "Customer created successfully."
    else
      @customer.build_billing_address_with_archived(address_type: "billing") if @customer.billing_address_with_archived.nil?
      @customer.shipping_addresses_with_archived.build(address_type: "shipping") if @customer.shipping_addresses_with_archived.empty?
      @customer_categories = current_organisation.customer_categories.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @customer = Customer.find(params[:id])
    @customer_categories = current_organisation.customer_categories.ordered
    @customer.build_billing_address_with_archived if @customer.billing_address_with_archived.nil?
    @customer.shipping_addresses_with_archived.build if @customer.shipping_addresses_with_archived.empty?
  end

  def update
    attrs = customer_params.to_h
    # When an admin manually fills external_id (the "Marcar sincronizado"
    # flow), tag the source so future ERP syncs treat the row consistently
    # with auto-imported customers.
    if attrs["external_id"].present? && @customer.external_id.blank?
      attrs["external_source"] = current_organisation.erp_configuration&.adapter_type.presence || "manual"
      attrs["last_synced_at"] = Time.current
    end
    if @customer.update(attrs)
      @customer.reload
      msg = if attrs["external_id"].present? && attrs["external_source"].present?
              "Cliente marcado como sincronizado. Encomendas pendentes vão ser enviadas para o ERP."
            else
              "Customer updated successfully."
            end
      redirect_to bo_customer_path(params[:org_slug], @customer, filter_params_hash), notice: msg
    else
      @customer_categories = current_organisation.customer_categories.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to bo_customers_path(params[:org_slug], filter_params_hash), status: :see_other, notice: "Customer deleted successfully."
  end

  # Lazy-loaded modal for managing a customer's logins (CustomerUsers) from
  # any listing page. Returns turbo_stream that appends the modal to a stable
  # body-level target. The modal lets a rep create/edit logins and trigger
  # the invitation share flow without leaving the carteira / customers list.
  def logins_modal
    @customer_users = @customer.customer_users.order(:created_at)
    @new_customer_user = @customer.customer_users.build
    respond_to(&:turbo_stream)
  end

  helper_method :filter_params_hash, :sort_link_params, :parse_db_time

  private

  # Aggregate columns from load_customers come back as raw values that may be
  # a String or a Time depending on the adapter — normalise to a zoned Time.
  def parse_db_time(value)
    return if value.blank?

    value.is_a?(Time) ? value : Time.zone.parse(value.to_s)
  end

  def exportable_class
    Customer
  end

  def exportable_base_scope
    policy_scope(current_organisation.customers).includes(:customer_category, :customer_users)
  end

  def apply_export_filters(scope)
    apply_customer_filters(scope)
  end

  def filter_params_hash
    { query: params[:query], status: params[:status], category: params[:category],
      sort: params[:sort], direction: params[:direction], page: params[:page] }.compact_blank
  end

  def sort_link_params(column)
    direction = (@sort_column == column && @sort_direction == "asc") ? "desc" : "asc"
    filter_params_hash.except(:page).merge(sort: column, direction: direction)
  end

  def customer_params
    raw = params.require(:customer).permit(
      :company_name, :contact_name, :email, :contact_phone, :active,
      :taxpayer_id, :email_notifications_enabled, :customer_category_id,
      :external_id,
      billing_address_with_archived_attributes: [:id, :street_name, :street_nr, :postal_code, :city, :country, :address_type, :active],
      shipping_addresses_with_archived_attributes: [:id, :street_name, :street_nr, :postal_code, :city, :country, :address_type, :_destroy, :active]
    )

    # external_id is the ERP id — never settable by reps; only admins/owners
    # can mark a customer as synced manually (or it's filled by ERP sync).
    raw = raw.except(:external_id) unless current_org_member&.role&.in?(%w[owner admin])

    return raw unless pure_sales_rep?

    # Pure reps can't set pricing tier (customer_category) or toggle active state.
    # On update: NIF + billing address are locked (immutable identity / anti-fraud).
    # Shipping addresses can have NEW entries appended, but existing ones can't
    # be edited or deleted — strip any sub-hash carrying an :id from the
    # nested-attributes payload so only fresh additions go through.
    restricted = raw.except(:customer_category_id, :active)
    if action_name == "update"
      restricted = restricted.except(:taxpayer_id, :billing_address_with_archived_attributes)

      ship_attrs = restricted[:shipping_addresses_with_archived_attributes]
      restricted[:shipping_addresses_with_archived_attributes] = strip_existing_address_attrs(ship_attrs) if ship_attrs.present?
    end
    restricted
  end

  # Filters a nested-attributes payload (array or hash form) down to entries
  # that are new records (no :id). Protects pure-rep updates from sneaking in
  # edits or destroys against existing shipping address rows.
  def strip_existing_address_attrs(attrs)
    case attrs
    when Array
      attrs.reject { |a| a[:id].present? || a["id"].present? }
    when ActionController::Parameters, Hash
      attrs.reject { |_, a| (a[:id].presence || a["id"].presence).present? }
    else
      attrs
    end
  end

  def load_customers
    scope = apply_customer_filters(
      policy_scope(current_organisation.customers)
        .includes(:customer_category, :customer_users, customer_assignment: { org_member: :member })
    )

    # Aggregate login/invitation data per empresa (a Customer may have N logins).
    #   last_access_at     = most recent login across all logins
    #   total_sign_in_count = summed login count
    #   first_invited_at / first_accepted_at = earliest invite / acceptance
    login_agg = CustomerUser
      .select("customer_id, MAX(last_sign_in_at) AS last_access_at, " \
              "COALESCE(SUM(sign_in_count), 0) AS total_sign_in_count, " \
              "MIN(invitation_sent_at) AS first_invited_at, " \
              "MIN(invitation_accepted_at) AS first_accepted_at")
      .group(:customer_id)

    scope = scope
      .joins("LEFT JOIN (#{login_agg.to_sql}) login_agg ON login_agg.customer_id = customers.id")
      .select("customers.*, login_agg.last_access_at, login_agg.total_sign_in_count, " \
              "login_agg.first_invited_at, login_agg.first_accepted_at")

    @sort_column = %w[company_name contact_name email active last_access].include?(params[:sort]) ? params[:sort] : "company_name"
    @sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
    @customers = if @sort_column == "last_access"
      dir = @sort_direction == "asc" ? "ASC" : "DESC"
      scope.order(Arel.sql("login_agg.last_access_at #{dir} NULLS LAST"))
    else
      scope.order(@sort_column => @sort_direction)
    end
    @pagy, @customers = pagy(@customers)

    @last_customer_sync = current_organisation.erp_sync_logs.for_entity('customers').completed.recent.first if current_organisation.erp_configuration&.enabled?
  end

  def apply_customer_filters(scope)
    if params[:query].present?
      scope = scope.where(
        "unaccent(company_name) ILIKE unaccent(:q) OR unaccent(contact_name) ILIKE unaccent(:q) OR unaccent(email) ILIKE unaccent(:q) OR unaccent(external_id) ILIKE unaccent(:q)",
        q: "%#{params[:query]}%"
      )
    end

    case params[:status]
    when "pending_erp_sync"
      scope = scope.pending_erp_sync if erp_customer_sync_enabled?
    when "no_rep"
      scope = scope.left_joins(:customer_assignment).where(customer_assignments: { id: nil })
    when "no_email"
      # The rep's call/visit list: empresas that can't be invited until someone
      # collects an address. They can still be sold to via impersonation.
      scope = scope.without_email
    when "active"
      # Has at least one active login that has accepted its invitation.
      scope = scope.where(active: true)
                   .joins(:customer_users)
                   .where(customer_users: { active: true })
                   .where.not(customer_users: { invitation_accepted_at: nil })
                   .distinct
    when "inactive"
      # Customer.active = false OR has logins but all are deactivated.
      scope = scope.where(<<~SQL.squish)
        customers.active = FALSE
        OR (
          customers.active = TRUE
          AND EXISTS (SELECT 1 FROM customer_users cu WHERE cu.customer_id = customers.id)
          AND NOT EXISTS (SELECT 1 FROM customer_users cu WHERE cu.customer_id = customers.id AND cu.active = TRUE)
        )
      SQL
    when "pending"
      # At least one login invited but none accepted yet.
      accepted_ids = Customer.joins(:customer_users)
                             .where.not(customer_users: { invitation_accepted_at: nil })
                             .select(:id)
      scope = scope.where(active: true)
                   .joins(:customer_users)
                   .where.not(customer_users: { invitation_sent_at: nil })
                   .where.not(id: accepted_ids)
                   .distinct
    when "not_invited"
      # No logins yet, or none have been invited.
      invited_ids = Customer.joins(:customer_users)
                            .where.not(customer_users: { invitation_sent_at: nil })
                            .select(:id)
      scope = scope.where(active: true).where.not(id: invited_ids)
    when "stale_pending"
      # At least one login invited >= 7 days ago and none accepted.
      accepted_ids = Customer.joins(:customer_users)
                             .where.not(customer_users: { invitation_accepted_at: nil })
                             .select(:id)
      scope = scope.where(active: true)
                   .joins(:customer_users)
                   .where("customer_users.invitation_sent_at <= ?", 7.days.ago)
                   .where.not(id: accepted_ids)
                   .distinct
    end

    case params[:activity]
    when "online_now"
      scope = scope.joins(:customer_users)
                   .where("customer_users.last_seen_at >= ?", 5.minutes.ago)
                   .distinct
    when "active_week"
      scope = scope.joins(:customer_users)
                   .where("customer_users.current_sign_in_at >= ?", 7.days.ago)
                   .distinct
    when "accepted_no_return"
      placed_customer_ids   = current_organisation.orders.placed.distinct.select(:customer_id)
      returning_ids         = current_organisation.customers.joins(:customer_users)
                                .where("customer_users.sign_in_count > 1").select(:id)
      accepted_ids          = current_organisation.customers.joins(:customer_users)
                                .where.not(customer_users: { invitation_accepted_at: nil }).select(:id)
      scope = scope.where(id: accepted_ids)
                   .where.not(id: returning_ids)
                   .where.not(id: placed_customer_ids)
    when "dormant"
      returning_ids   = current_organisation.customers.joins(:customer_users)
                          .where("customer_users.sign_in_count > 1").select(:id)
      recently_active = current_organisation.customers.joins(:customer_users)
                          .where("customer_users.current_sign_in_at >= ?", 30.days.ago).select(:id)
      scope = scope.where(id: returning_ids).where.not(id: recently_active)
    when "engaged_no_orders"
      placed_customer_ids = current_organisation.orders.placed.distinct.select(:customer_id)
      returning_ids       = current_organisation.customers.joins(:customer_users)
                              .where("customer_users.sign_in_count > 1").select(:id)
      recently_active     = current_organisation.customers.joins(:customer_users)
                              .where("customer_users.current_sign_in_at >= ?", 30.days.ago).select(:id)
      scope = scope.where(id: returning_ids)
                   .where(id: recently_active)
                   .where.not(id: placed_customer_ids)
    end

    scope = scope.where(customer_category_id: params[:category]) if params[:category].present?

    scope
  end

  def set_and_authorize_customer
    @customer = current_organisation.customers.find(params[:id])
    authorize @customer
  end
end
