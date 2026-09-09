module AnalyticsHelper
  # Chart.js config for a single chart card. `series_data` is the hash
  # returned by Dashboard::Metrics.time_series.
  def analytics_chart_config(key, series_data)
    palette = %w[#5B5BD6 #2EA89C #D97757 #6F6F6F]
    {
      type: "line",
      data: {
        labels: series_data[:labels].map(&:to_s),
        datasets: series_data[:series].each_with_index.map do |s, i|
          color = palette[i % palette.length]
          {
            label: t("bo.analytics.series.#{s[:label]}", default: s[:label].titleize),
            data: s[:data],
            borderColor: color,
            backgroundColor: "#{color}33",
            tension: 0.3,
            fill: false,
            pointRadius: 2,
            pointHoverRadius: 4
          }
        end
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: series_data[:series].size > 1, position: "bottom" },
          tooltip: { mode: "index", intersect: false }
        },
        scales: {
          y: { beginAtZero: true, ticks: { precision: 0 } }
        }
      }
    }
  end
end
