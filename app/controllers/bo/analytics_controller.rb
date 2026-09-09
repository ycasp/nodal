# frozen_string_literal: true

class Bo::AnalyticsController < Bo::BaseController
  skip_after_action :verify_policy_scoped, only: :index

  CHART_METRICS = %i[sales orders aov unique_customers logins carts avg_interval].freeze

  # GET /bo/analytics
  def index
    if pure_sales_rep?
      redirect_to bo_sales_rep_carteira_path(org_slug: current_organisation.slug)
      return
    end

    authorize :dashboard, :index?

    @from        = parse_date(params[:from], default: 30.days.ago.to_date)
    @to          = parse_date(params[:to], default: Date.current)
    @granularity = parse_granularity(params[:granularity])
    @client_id   = params[:client_id].presence

    @charts = CHART_METRICS.each_with_object({}) do |metric, h|
      h[metric] = Dashboard::Metrics.time_series(
        organisation: current_organisation,
        metric: metric,
        from: @from,
        to: @to,
        granularity: @granularity,
        client_id: @client_id
      )
    end
  end

  private

  def parse_date(value, default:)
    return default if value.blank?
    Date.parse(value)
  rescue ArgumentError
    default
  end

  def parse_granularity(value)
    return :day if value.blank?
    sym = value.to_sym
    %i[day week month].include?(sym) ? sym : :day
  end
end
