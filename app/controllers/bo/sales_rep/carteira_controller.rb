module Bo
  module SalesRep
    # Personal carteira view for any OrgMember with `is_sales_rep: true`.
    # Lists the customers they're assigned to, with last-order metadata,
    # invitation-status filters, ERP sync state and an open-cart indicator.
    class CarteiraController < Bo::BaseController
      def index
        unless current_org_member&.is_sales_rep?
          flash[:alert] = "Esta página é só para vendedores."
          redirect_to bo_path(org_slug: current_organisation.slug) and return
        end

        skip_authorization
        skip_policy_scope

        base_scope = current_organisation
                       .customers
                       .joins(:customer_assignment)
                       .where(customer_assignments: { org_member_id: current_org_member.id })
                       .includes(:customer_assignment, :customer_users)

        @customers = apply_carteira_filters(base_scope)

        @sort_column = %w[company_name contact_name last_order_at].include?(params[:sort]) ? params[:sort] : "company_name"
        @sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"

        if @sort_column == "last_order_at"
          # Correlated subquery: order customers by their most-recent placed_at.
          # NULLS LAST so customers without any placed order land at the bottom on ASC too.
          @customers = @customers.order(
            Arel.sql(
              "(SELECT MAX(placed_at) FROM orders " \
              "WHERE orders.customer_id = customers.id AND placed_at IS NOT NULL) " \
              "#{@sort_direction.upcase} NULLS LAST"
            )
          )
        else
          @customers = @customers.order(@sort_column => @sort_direction)
        end

        @pagy, @customers = pagy(@customers)

        # Pre-load per-customer aggregates to avoid N+1 in the view.
        customer_ids = @customers.map(&:id)
        @last_order_at = current_organisation.orders.placed.where(customer_id: customer_ids).group(:customer_id).maximum(:placed_at)
        @customer_ids_online = current_organisation.customer_users
                                 .where(customer_id: customer_ids)
                                 .where("last_seen_at >= ?", 5.minutes.ago)
                                 .distinct.pluck(:customer_id).to_set

        # Invitation KPIs scoped to this rep's carteira (not the whole org).
        carteira_scope = current_organisation.customers
                           .joins(:customer_assignment)
                           .where(customer_assignments: { org_member_id: current_org_member.id })
        @carteira_kpis = ::Dashboard::Metrics
          .customer_health(organisation: current_organisation, customers_scope: carteira_scope)
          .slice(:total_customers, :active_users, :pending_users, :stale_pending_users, :uninvited_users,
                 :no_email_users)

        load_kpis_and_open_carts
      end

      helper_method :carteira_filter_params_hash, :carteira_sort_link_params

      def carteira_filter_params_hash
        { query: params[:query], status: params[:status], erp_status: params[:erp_status],
          sort: params[:sort], direction: params[:direction], page: params[:page] }.compact_blank
      end

      def carteira_sort_link_params(column)
        direction = (@sort_column == column && @sort_direction == "asc") ? "desc" : "asc"
        carteira_filter_params_hash.except(:page).merge(sort: column, direction: direction)
      end

      private

      def apply_carteira_filters(scope)
        if params[:query].present?
          q = "%#{params[:query]}%"
          scope = scope.where(
            "unaccent(customers.company_name) ILIKE unaccent(:q) " \
            "OR unaccent(customers.contact_name) ILIKE unaccent(:q) " \
            "OR unaccent(customers.email) ILIKE unaccent(:q) " \
            "OR unaccent(customers.taxpayer_id) ILIKE unaccent(:q)",
            q: q
          )
        end

        case params[:status]
        when "active"
          scope = scope.where(customers: { active: true })
                       .joins(:customer_users)
                       .where(customer_users: { active: true })
                       .where.not(customer_users: { invitation_accepted_at: nil })
                       .distinct
        when "pending"
          accepted_ids = Customer.joins(:customer_users)
                                 .where.not(customer_users: { invitation_accepted_at: nil })
                                 .select(:id)
          scope = scope.where(customers: { active: true })
                       .joins(:customer_users)
                       .where.not(customer_users: { invitation_sent_at: nil })
                       .where.not(customers: { id: accepted_ids })
                       .distinct
        when "not_invited"
          invited_ids = Customer.joins(:customer_users)
                                .where.not(customer_users: { invitation_sent_at: nil })
                                .select(:id)
          scope = scope.where(customers: { active: true }).where.not(customers: { id: invited_ids })
        when "inactive"
          scope = scope.where(<<~SQL.squish)
            customers.active = FALSE
            OR (
              customers.active = TRUE
              AND EXISTS (SELECT 1 FROM customer_users cu WHERE cu.customer_id = customers.id)
              AND NOT EXISTS (SELECT 1 FROM customer_users cu WHERE cu.customer_id = customers.id AND cu.active = TRUE)
            )
          SQL
        when "no_email"
          # The rep's call/visit list: empresas the ERP has no address for, so
          # they can't be invited yet. Still sellable through impersonation.
          scope = scope.without_email
        end

        case params[:erp_status]
        when "synced"
          scope = scope.where.not(customers: { external_id: nil })
        when "pending"
          scope = scope.where(customers: { external_id: nil })
        end

        scope
      end

      def load_kpis_and_open_carts
        # "Meus números": all placed orders from customers in this rep's
        # carteira plus any orders this rep personally placed.
        carteira_customer_ids = current_org_member.customer_assignments.pluck(:customer_id)
        rep_orders = current_organisation.orders.placed.where(
          "orders.customer_id IN (?) OR orders.sales_rep_id = ?",
          carteira_customer_ids,
          current_org_member.id
        )
        currency = current_organisation.currency

        this_month_orders = rep_orders.where(placed_at: Time.current.beginning_of_month..Time.current.end_of_month)
        last_month_orders = rep_orders.where(placed_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month)

        @kpi_orders_this_month = this_month_orders.count
        @kpi_orders_last_month = last_month_orders.count

        this_month_total_cents = this_month_orders.sum { |o| o.grand_total.cents rescue 0 }
        last_month_total_cents = last_month_orders.sum { |o| o.grand_total.cents rescue 0 }

        @kpi_revenue_this_month = Money.new(this_month_total_cents, currency)
        @kpi_revenue_last_month = Money.new(last_month_total_cents, currency)

        @kpi_aov_this_month = @kpi_orders_this_month > 0 ? Money.new(this_month_total_cents / @kpi_orders_this_month, currency) : Money.new(0, currency)
        @kpi_aov_last_month = @kpi_orders_last_month > 0 ? Money.new(last_month_total_cents / @kpi_orders_last_month, currency) : Money.new(0, currency)

        # Open carts: draft orders WITH AT LEAST ONE ITEM, scoped to this
        # rep's carteira customers. Same logic as Dashboard::Metrics open_carts
        # but filtered to the carteira. Loaded with the same eager-loads as
        # Dashboard::Metrics.open_carts_detail so the shared modal partial
        # (bo/dashboards/_open_carts_modal) renders without N+1.
        @open_carts = current_organisation.orders.draft
                        .where(customer_id: carteira_customer_ids)
                        .joins(:order_items)
                        .distinct
                        .includes(:customer, :customer_user, order_items: [:product, :product_variant])
                        .order(created_at: :desc)
                        .to_a

        @kpi_open_carts = @open_carts.size
        open_carts_total_cents = @open_carts.sum do |cart|
          cart.order_items.sum { |item| item.total_price.cents }
        end
        @kpi_open_carts_total = Money.new(open_carts_total_cents, currency)

        # For the row badge: which customers in the (paginated) listing
        # currently have at least one open cart with items.
        @customer_ids_with_open_carts = @open_carts.map(&:customer_id).to_set
      end
    end
  end
end
