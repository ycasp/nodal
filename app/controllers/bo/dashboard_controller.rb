# frozen_string_literal: true

class Bo::DashboardController < Bo::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # GET /bo/dashboard
  def index
    @organisation = current_organisation
  end

  # GET /bo/dashboard/metrics
  # Returns JSON with all KPI data
  def metrics
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
