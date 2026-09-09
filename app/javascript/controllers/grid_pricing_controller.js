import { Controller } from "@hotwired/stimulus"

// Live pricing for the bulk grid (variable product, grid add-to-cart mode).
// Rows have independent quantities. The server passes each variant's locked
// (condition unmet) and unlocked (met) unit prices.
//
// - per_line scope: each row flips to its unlocked price when its own qty
//   (+ that variant's cart line) clears the threshold.
// - summed scope: one tracker at the foot sums every row (+ the product's cart
//   total) and, once met, flips every row to its unlocked price and celebrates.
export default class extends Controller {
  static targets = ["rowInput", "rowPrice", "rowOriginal", "buttonTotal"]
  // The summed tracker is shown in the discounts panel (above the grid), driven
  // through the product-pricing controller — same place/look as simple products.
  static outlets = ["product-pricing"]
  static values = {
    pricing: Object,       // { [vid]: { locked, unlocked, base, cart } }
    conditionType: String, // quantity | amount | none
    threshold: Number,     // units or cents
    scope: String,         // per_line | summed | none
    cartSummed: Number,    // product/category cart total toward a summed threshold
    currencySymbol: String
  }

  connect() {
    this.update()
  }

  update() {
    let grandTotal = 0
    if (this.scopeValue === "summed") {
      grandTotal = this.updateSummed()
    } else if (this.scopeValue === "none") {
      // No condition: just sum the rows for the button total.
      this.rowInputTargets.forEach((input) => {
        const p = this.pricingFor(input)
        if (p) grandTotal += this.qtyOf(input) * p.locked
      })
    } else {
      this.rowInputTargets.forEach((input) => { grandTotal += this.updatePerLineRow(input) })
    }
    this.updateButtonTotal(grandTotal)
  }

  // --- per-line: each row independent. Returns the row's € contribution. --
  updatePerLineRow(input) {
    const p = this.pricingFor(input)
    if (!p) return 0
    const qty = this.qtyOf(input)
    const contribution = this.conditionTypeValue === "amount" ? qty * p.base : qty
    const met = (p.cart || 0) + contribution >= this.thresholdValue
    const unit = met ? p.unlocked : p.locked
    this.setRowPrice(input, unit, p.base)
    return qty * unit
  }

  // --- summed: all rows share one threshold. Returns the grid € total. ----
  updateSummed() {
    let toward = this.cartSummedValue || 0
    this.rowInputTargets.forEach((input) => {
      const p = this.pricingFor(input)
      if (!p) return
      const qty = this.qtyOf(input)
      toward += this.conditionTypeValue === "amount" ? qty * p.base : qty
    })
    const met = toward >= this.thresholdValue

    let total = 0
    this.rowInputTargets.forEach((input) => {
      const p = this.pricingFor(input)
      if (!p) return
      const unit = met ? p.unlocked : p.locked
      this.setRowPrice(input, unit, p.base)
      total += this.qtyOf(input) * unit
    })

    // The panel tracker (product-pricing) renders from the running aggregate.
    if (this.hasProductPricingOutlet) this.productPricingOutlet.renderSummedTracker(toward)
    return total
  }

  productPricingOutletConnected() {
    this.update()
  }

  updateButtonTotal(cents) {
    if (!this.hasButtonTotalTarget) return
    this.buttonTotalTarget.textContent = cents > 0 ? ` · ${this.formatPrice(cents)}` : ""
  }

  // --- helpers ----------------------------------------------------------
  pricingFor(input) {
    return this.pricingValue[input.dataset.variantId]
  }

  qtyOf(input) {
    return Math.max(parseInt(input.value, 10) || 0, 0)
  }

  setRowPrice(input, unit, base) {
    const tr = input.closest("tr")
    if (!tr) return
    const priceEl = tr.querySelector("[data-grid-pricing-target='rowPrice']")
    const origEl = tr.querySelector("[data-grid-pricing-target='rowOriginal']")
    const discounted = unit < base
    if (priceEl) {
      priceEl.textContent = this.formatPrice(unit)
      priceEl.classList.toggle("text-success", discounted)
      priceEl.classList.toggle("fw-medium", discounted)
    }
    if (origEl) origEl.classList.toggle("d-none", !discounted)
  }

  formatPrice(cents) {
    return `${this.currencySymbolValue}${(cents / 100).toFixed(2)}`
  }
}
