import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "total"]
  static values = { pricingUrl: String, customerId: String }

  connect() {
    this.index = this.containerTarget.querySelectorAll("tr").length
    this.updateTotal()
  }

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
    this.index++
    this.updateTotal()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("tr")

    // If there's a hidden _destroy field, mark it for destruction
    const destroyInput = row.querySelector("input[name*='_destroy']")
    if (destroyInput) {
      destroyInput.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }

    this.updateTotal()
  }

  // Picking a variant fills the line with what the shop would charge this
  // customer — the variant's price and the discount its rules work out. Both
  // land in editable fields: this is where the line starts, not what it must be.
  variantChanged(event) {
    const row = event.target.closest("tr")
    const variantId = event.target.value

    const productInput = row.querySelector("input[name*='[product_id]']")
    if (!variantId) {
      if (productInput) productInput.value = ""
      this.calculateLineTotal(row)
      this.updateTotal()
      return
    }

    const url = new URL(this.pricingUrlValue, window.location.origin)
    url.searchParams.set("variant_id", variantId)
    url.searchParams.set("quantity", row.querySelector("[data-quantity-field]")?.value || 1)
    const customerId = this.customerId()
    if (customerId) url.searchParams.set("customer_id", customerId)

    // What the fields held when the request went out. If the person has typed
    // since, that is a deliberate value and the answer must not land on top of
    // it — the whole point of these fields is that they can be overridden.
    const priceInput = row.querySelector("[data-price-field]")
    const discountInput = row.querySelector("[data-discount-field]")
    const priceBefore = priceInput?.value
    const discountBefore = discountInput?.value

    fetch(url, { headers: { Accept: "application/json" } })
      .then(response => response.json())
      .then(pricing => {
        // The line belongs to the variant's product; the form never picks it.
        if (productInput) productInput.value = pricing.product_id

        if (priceInput && priceInput.value === priceBefore) {
          priceInput.value = Number(pricing.unit_price).toFixed(2)
        }

        if (discountInput && discountInput.value === discountBefore) {
          discountInput.value = (Number(pricing.discount_percentage) * 100).toFixed(2)
        }

        this.calculateLineTotal(row)
        this.updateTotal()
      })
      .catch(() => {
        this.calculateLineTotal(row)
        this.updateTotal()
      })
  }

  // The order's customer decides the pricing. On the edit screen it is fixed;
  // on the new-order screen it is whatever the form has selected so far.
  customerId() {
    if (this.hasCustomerIdValue && this.customerIdValue) return this.customerIdValue

    const select = document.querySelector("select[name='order[customer_id]']")
    return select ? select.value : null
  }

  calculate(event) {
    const row = event.target.closest("tr")
    this.calculateLineTotal(row)
    this.updateTotal()
  }

  calculateLineTotal(row) {
    const quantity = parseFloat(row.querySelector("[data-quantity-field]")?.value) || 0
    const unitPrice = parseFloat(row.querySelector("[data-price-field]")?.value) || 0
    // The discount is part of the line, so the total on screen has to include
    // it: OrderItem#total_price subtracts it, and until now this did not — the
    // figure shown while editing was not the figure that got saved.
    const discount = (parseFloat(row.querySelector("[data-discount-field]")?.value) || 0) / 100
    const lineTotal = quantity * unitPrice * (1 - discount)

    const lineTotalEl = row.querySelector("[data-line-total]")
    if (lineTotalEl) {
      lineTotalEl.textContent = lineTotal.toFixed(2)
    }
  }

  updateTotal() {
    const lineTotals = this.containerTarget.querySelectorAll("[data-line-total]")
    let total = 0

    lineTotals.forEach(el => {
      const row = el.closest("tr")
      if (row && row.style.display !== "none") {
        total += parseFloat(el.textContent) || 0
      }
    })

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = total.toFixed(2)
    }
  }
}
