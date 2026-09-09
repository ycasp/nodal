# frozen_string_literal: true

class Bo::DashboardsController < Bo::BaseController
  skip_after_action :verify_policy_scoped, only: :index

  # GET /bo/dashboards
  def index
    @organisation = current_organisation
    authorize :dashboard, :index?
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
