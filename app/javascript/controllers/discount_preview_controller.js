import { Controller } from "@hotwired/stimulus"

// Computes live price previews for variant overrides in the product discount form.
// Reads the main discount fields (discount_type, discount_value) from the parent form
// and combines them with per-variant overrides (exclude, custom discount) to show
// the final price for each variant.
export default class extends Controller {
  static targets = ["row", "finalPrice", "exclude", "customType", "customValue"]
  static values = { symbol: String }

  connect() {
    this.bindFormFields()
    this.recalculate()
  }

  bindFormFields() {
    const form = this.element.closest("form")
    if (!form) return

    this.discountTypeField = form.querySelector("[name$='[discount_type]']")
    this.discountValueField = form.querySelector("[name$='[discount_value]']") || form.querySelector("[name$='[discount_percentage]']")

    if (this.discountTypeField) {
      this.discountTypeField.addEventListener("change", () => this.recalculate())
    }
    if (this.discountValueField) {
      this.discountValueField.addEventListener("input", () => this.recalculate())
    }
  }

  recalculate() {
    const mainType = this.discountTypeField?.value || "percentage"
    const mainValue = parseFloat(this.discountValueField?.value) || 0

    this.rowTargets.forEach((row, index) => {
      const priceCents = parseInt(row.dataset.priceCents) || 0
      const priceDisplay = this.finalPriceTargets[index]
      if (!priceDisplay) return

      const excludeCheckbox = this.excludeTargets[index]
      const customTypeSelect = this.customTypeTargets[index]
      const customValueInput = this.customValueTargets[index]

      const excluded = excludeCheckbox?.checked
      const customType = customTypeSelect?.value
      const customValue = parseFloat(customValueInput?.value) || 0

      let finalCents = priceCents

      if (excluded) {
        // No discount — show base price
        finalCents = priceCents
        priceDisplay.innerHTML = `<span class="text-muted">${this.formatMoney(finalCents)}</span>`
      } else if (customType && customValue > 0) {
        // Custom variant discount overrides product discount
        finalCents = this.applyDiscount(priceCents, customType, customValue)
        priceDisplay.innerHTML = this.priceHtml(priceCents, finalCents)
      } else if (mainValue > 0) {
        // Product-level discount
        finalCents = this.applyDiscount(priceCents, mainType, mainValue)
        priceDisplay.innerHTML = this.priceHtml(priceCents, finalCents)
      } else {
        priceDisplay.innerHTML = `<span class="text-muted">${this.formatMoney(priceCents)}</span>`
      }
    })
  }

  applyDiscount(priceCents, type, value) {
    if (type === "percentage") {
      return Math.round(priceCents * (1 - value))
    } else {
      // Fixed discount: value is in currency units (e.g. 1.50 = 150 cents)
      return Math.max(0, priceCents - Math.round(value * 100))
    }
  }

  priceHtml(originalCents, finalCents) {
    if (finalCents >= originalCents) {
      return `<span class="text-muted">${this.formatMoney(originalCents)}</span>`
    }
    return `<span class="text-success fw-semibold">${this.formatMoney(finalCents)}</span>`
  }

  formatMoney(cents) {
    const amount = (cents / 100).toFixed(2)
    return `${this.symbolValue}\u00A0${amount}`
  }
}
