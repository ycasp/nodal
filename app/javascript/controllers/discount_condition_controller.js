import { Controller } from "@hotwired/stimulus"

// Shows the quantity OR amount field for a discount condition, based on the
// condition_type select ("none" shows neither).
// Connects to data-controller="discount-condition"
export default class extends Controller {
  static targets = ["select", "quantity", "amount", "scope"]

  connect() {
    this.update()
  }

  update() {
    const value = this.selectTarget.value
    if (this.hasQuantityTarget) {
      this.quantityTarget.style.display = value === "quantity" ? "" : "none"
    }
    if (this.hasAmountTarget) {
      this.amountTarget.style.display = value === "amount" ? "" : "none"
    }
    // Scope (per-line vs summed) only matters when there's a condition.
    if (this.hasScopeTarget) {
      this.scopeTarget.style.display = value === "none" ? "none" : ""
    }
  }
}
