import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dashboard"
export default class extends Controller {
  static targets = ["from", "to", "client", "category"]
  static values = { metricsUrl: String, currency: String }

  connect() {
    console.log("Dashboard controller connected")
    this.setDefaultDates()
    this.loadMetrics()
  }

  setDefaultDates() {
    const today = new Date()
    const thirtyDaysAgo = new Date(today)
    thirtyDaysAgo.setDate(today.getDate() - 30)

    if (this.hasFromTarget && !this.fromTarget.value) {
      this.fromTarget.value = thirtyDaysAgo.toISOString().split('T')[0]
    }
    if (this.hasToTarget && !this.toTarget.value) {
      this.toTarget.value = today.toISOString().split('T')[0]
    }
  }

  applyFilters() {
    this.loadMetrics()
  }

  loadMetrics() {
    const params = new URLSearchParams()
    if (this.hasFromTarget && this.fromTarget.value) params.set('from', this.fromTarget.value)
    if (this.hasToTarget && this.toTarget.value) params.set('to', this.toTarget.value)
    if (this.hasClientTarget && this.clientTarget.value) params.set('client_id', this.clientTarget.value)
    if (this.hasCategoryTarget && this.categoryTarget.value) params.set('category_id', this.categoryTarget.value)

    const url = `${this.metricsUrlValue}?${params.toString()}`
    console.log("Loading metrics from:", url)

    // Show loading state
    document.querySelectorAll('.kpi__value').forEach(el => {
      el.textContent = '...'
    })

    fetch(url, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
      .then(response => response.json())
      .then(data => {
        console.log("Metrics loaded:", data)
        this.updateDashboard(data)
      })
      .catch(error => {
        console.error('Failed to load metrics:', error)
      })
  }

  updateDashboard(data) {
    // Update KPI cards
    this.updateKpiCard('total_sales', data.kpis?.total_sales)
    this.updateKpiCard('order_count', data.kpis?.order_count)
    this.updateKpiCard('aov', data.kpis?.aov)
    this.updateOpenCarts(data.kpis?.open_carts)

    // Update other sections
    this.updateTopClients(data.top_clients)
    this.updateOrderFrequency(data.order_frequency)
    this.updateOrdersPerProduct(data.orders_per_product)
    this.updateRevenuePerProduct(data.revenue_per_product)
    this.updateDiscountPanel(data.discounts)
  }

  updateKpiCard(id, kpi) {
    if (!kpi) return

    const card = document.querySelector(`[data-kpi="${id}"]`)
    if (!card) return

    const valueEl = card.querySelector('.kpi__value')
    const deltaEl = card.querySelector('.kpi__delta')
    const canvas = card.querySelector('.kpi__sparkline')

    if (valueEl) {
      const format = card.dataset.format
      valueEl.textContent = this.formatValue(kpi.value, format)
    }

    if (deltaEl && kpi.delta_pct !== undefined) {
      const delta = kpi.delta_pct
      deltaEl.textContent = (delta >= 0 ? '+' : '') + delta.toFixed(1) + '%'
      deltaEl.className = 'kpi__delta ' + (delta >= 0 ? 'delta--up' : 'delta--down')
    }

    if (canvas && kpi.sparkline) {
      this.drawSparkline(canvas, kpi.sparkline)
    }
  }

  updateOpenCarts(openCarts) {
    if (!openCarts) return

    const card = document.querySelector('[data-kpi="open_carts"]')
    if (!card) return

    const valueEl = card.querySelector('.kpi__value')
    if (valueEl) valueEl.textContent = openCarts.value

    const listEl = card.querySelector('.kpi__carts-list')
    if (listEl && openCarts.top_carts) {
      listEl.innerHTML = openCarts.top_carts.slice(0, 3).map(cart => `
        <div class="kpi__cart-item">
          <span class="kpi__cart-client">${this.escapeHtml(cart.client_name)}</span>
          <span class="kpi__cart-total">${this.formatValue(cart.cart_total, 'currency')}</span>
        </div>
      `).join('')
    }
  }

  updateTopClients(clients) {
    const list = document.getElementById('top-clients-list')
    if (!list || !clients) return

    list.innerHTML = clients.map((client, index) => `
      <div class="top-clients__item">
        <span class="top-clients__rank">${index + 1}</span>
        <div class="top-clients__info">
          <div class="top-clients__name">${this.escapeHtml(client.client_name)}</div>
          <div class="top-clients__sales">${this.formatValue(client.total_sales, 'currency')}</div>
        </div>
        <span class="top-clients__delta ${client.delta_pct >= 0 ? 'delta--up' : 'delta--down'}">
          ${client.delta_pct >= 0 ? '+' : ''}${client.delta_pct?.toFixed(1) || 0}%
        </span>
      </div>
    `).join('')
  }

  updateOrderFrequency(frequency) {
    if (!frequency) return

    const valueEl = document.querySelector('.frequency__value')
    const meanEl = document.querySelector('.frequency__mean')
    const medianEl = document.querySelector('.frequency__median')

    if (valueEl) valueEl.textContent = frequency.value?.toFixed(1) || '0'
    if (meanEl) meanEl.textContent = frequency.breakdown?.mean?.toFixed(1) || '0'
    if (medianEl) medianEl.textContent = frequency.breakdown?.median?.toFixed(1) || '0'

    // Draw distribution chart
    const chartEl = document.querySelector('.frequency__chart')
    if (chartEl && frequency.breakdown?.distribution) {
      this.drawDistributionChart(chartEl, frequency.breakdown.distribution)
    }
  }

  updateOrdersPerProduct(products) {
    const tbody = document.querySelector('#orders-per-product tbody')
    if (!tbody || !products) return

    tbody.innerHTML = products.map(product => `
      <tr>
        <td>${this.escapeHtml(product.product_name)}</td>
        <td class="text-end">${product.order_count}</td>
        <td><canvas class="product-sparkline" width="80" height="24" data-values="${(product.sparkline || []).join(',')}"></canvas></td>
      </tr>
    `).join('')

    // Draw sparklines
    tbody.querySelectorAll('.product-sparkline').forEach(canvas => {
      const values = canvas.dataset.values.split(',').filter(v => v).map(Number)
      if (values.length > 0) this.drawSparkline(canvas, values)
    })
  }

  updateRevenuePerProduct(products) {
    const tbody = document.querySelector('#revenue-per-product tbody')
    if (!tbody || !products) return

    tbody.innerHTML = products.map(product => `
      <tr>
        <td>${this.escapeHtml(product.product_name)}</td>
        <td class="text-end">${this.formatValue(product.gross_revenue, 'currency')}</td>
        <td class="text-end text-danger">${this.formatValue(product.discount_amount, 'currency')}</td>
        <td class="text-end fw-semibold">${this.formatValue(product.net_revenue, 'currency')}</td>
      </tr>
    `).join('')
  }

  updateDiscountPanel(discounts) {
    if (!discounts) return

    const usageEl = document.getElementById('discount-usage-rate')
    const avgEl = document.getElementById('discount-avg')
    const lostEl = document.getElementById('discount-revenue-lost')

    if (usageEl) usageEl.textContent = (discounts.usage_rate * 100).toFixed(1) + '%'
    if (avgEl) avgEl.textContent = this.formatValue(discounts.avg_discount_per_order, 'currency')
    if (lostEl) lostEl.textContent = this.formatValue(discounts.revenue_lost, 'currency')

    // Top discounted products
    const productsEl = document.getElementById('top-discounted-products')
    if (productsEl && discounts.top_discounted_products) {
      productsEl.innerHTML = discounts.top_discounted_products.map(p => `
        <div class="discount-item">
          <span>${this.escapeHtml(p.product_name)}</span>
          <span class="text-danger">${this.formatValue(p.discount_amount, 'currency')}</span>
        </div>
      `).join('')
    }

    // Top clients by discount
    const clientsEl = document.getElementById('top-clients-by-discount')
    if (clientsEl && discounts.top_clients_by_discount) {
      clientsEl.innerHTML = discounts.top_clients_by_discount.map(c => `
        <div class="discount-item">
          <span>${this.escapeHtml(c.client_name)}</span>
          <span class="text-danger">${this.formatValue(c.discount_amount, 'currency')}</span>
        </div>
      `).join('')
    }
  }

  formatValue(value, format) {
    if (value === null || value === undefined) return '--'

    if (format === 'currency') {
      return new Intl.NumberFormat('de-CH', {
        style: 'currency',
        currency: this.currencyValue || 'EUR',
        minimumFractionDigits: 2
      }).format(value)
    }

    return new Intl.NumberFormat('de-CH').format(value)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  drawSparkline(canvas, values) {
    if (!values || values.length === 0) return

    const ctx = canvas.getContext('2d')
    const width = canvas.width || 80
    const height = canvas.height || 24

    ctx.clearRect(0, 0, width, height)

    const max = Math.max(...values, 1)
    const min = Math.min(...values, 0)
    const range = max - min || 1

    const stepX = width / (values.length - 1 || 1)
    const padding = 2

    ctx.beginPath()
    ctx.strokeStyle = '#6366f1'
    ctx.lineWidth = 1.5

    values.forEach((value, i) => {
      const x = i * stepX
      const y = height - padding - ((value - min) / range) * (height - padding * 2)

      if (i === 0) {
        ctx.moveTo(x, y)
      } else {
        ctx.lineTo(x, y)
      }
    })

    ctx.stroke()
  }

  drawDistributionChart(container, distribution) {
    if (!distribution || distribution.length === 0) return

    const maxCustomers = Math.max(...distribution.map(d => d.customers), 1)
    const maxHeight = 60

    container.innerHTML = distribution.map(d => {
      const height = (d.customers / maxCustomers) * maxHeight
      return `
        <div class="frequency__bar" style="height: ${height}px;" title="${d.orders} orders: ${d.customers} customers">
          <span class="frequency__bar-label">${d.orders}</span>
        </div>
      `
    }).join('')
  }
}
