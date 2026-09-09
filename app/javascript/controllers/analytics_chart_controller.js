import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js"

// Renders a Chart.js line chart from a server-provided config (JSON in
// data-analytics-chart-config-value). One controller instance per chart
// card. Destroys the chart on disconnect to avoid leaks on Turbo navigations.
export default class extends Controller {
  static values = { config: Object }

  connect() {
    const canvas = this.element.querySelector("canvas")
    if (!canvas) return
    this.chart = new Chart(canvas, this.configValue)
  }

  disconnect() {
    this.chart?.destroy()
  }
}
