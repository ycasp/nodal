# frozen_string_literal: true

class Bo::DashboardsController < Bo::BaseController
  skip_after_action :verify_policy_scoped, only: :index

  # GET /bo/dashboards
  def index
    # Pure reps have no business on the org dashboard (leaks org-wide KPIs).
    # Send them to their personal carteira instead — that's their CRM home.
    if pure_sales_rep?
      redirect_to bo_sales_rep_carteira_path(org_slug: current_organisation.slug)
      return
    end

    @organisation = current_organisation
    authorize :dashboard, :index?
    @open_carts = Dashboard::Metrics.open_carts_detail(@organisation)
    @customer_health = Dashboard::Metrics.customer_health(organisation: @organisation)
  end

  # GET /bo/dashboards/metrics
  # Returns JSON with all KPI data
  def metrics
    authorize :dashboard
    metrics_service = Dashboard::Metrics.new(current_organisation)
    render json: metrics_service.to_json(metrics_params)
  rescue StandardError => e
    Rails.logger.error("Dashboard metrics error: #{e.message}")
    render json: { error: "Failed to load metrics" }, status: :internal_server_error
  end

  private

  def metrics_params
    params.permit(:from, :to, :client_id, :product_id, :category_id, :discount_type, :include_discounts)
  end
end
