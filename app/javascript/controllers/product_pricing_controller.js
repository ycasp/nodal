import { Controller } from "@hotwired/stimulus"

// Live pricing + unlock progress on the product page.
//
// Simple products: the server renders the locked/unlocked unit prices and the
// controller is active from connect().
//
// Variable products: the controller starts inert and the variant-selector
// feeds it the selected variant's prices via applyVariant() (Stimulus outlet).
// While no variant is selected it stays inert and leaves the header/total to
// the variant-selector's range display.
//
// To avoid re-implementing the discount engine in JS, the server passes two
// unit prices: lockedUnit (condition NOT met) and unlockedUnit (met). JS picks
// one based on whether the projected total reaches the threshold. `cartCurrent`
// is what's already in the cart toward the threshold (the line the page would
// merge into, or a summed product/category total).
export default class extends Controller {
  static targets = [
    "quantity", "total", "discountNote", "tracker", "trackerLine", "trackerIcon",
    "trackerText", "progressBar", "headerPrice", "headerOriginal", "panelUnmet", "panelBadge"
  ]
  static values = {
    lockedUnitCents: Number,
    unlockedUnitCents: Number,
    baseUnitCents: Number,
    conditionType: String, // none | quantity | amount
    threshold: Number,     // units (quantity) or cents (amount)
    cartCurrent: Number,
    cartCurrentLabel: String, // "12 unidades" — for the from-cart celebration
    discountLabel: String,
    currencySymbol: String,
    remainingTemplate: String, // "faltam %{remaining} para %{discount}"
    celebrationDefault: String,
    celebrationFromCartTemplate: String, // "%{discount} ... %{cart} ..." (cart filled in JS)
    discountAppliedTemplate: String, // "(%{discount} aplicado)"
    variantPricing: Object // { [variantId]: { locked_unit_cents, unlocked_unit_cents, base_unit_cents, cart_current, cart_current_label } }
  }

  connect() {
    // Grid mode: no quantity input here — the panel tracker is driven externally
    // by the grid-pricing controller via renderSummedTracker(). Stay passive.
    if (!this.hasQuantityTarget) return
    // Variable product: inert until a variant is applied. Simple: always active.
    this.active = !this.isVariable()
    this.update()
  }

  // Driven by grid-pricing (summed condition) to show the panel tracker from the
  // grid's aggregate, without a single quantity of its own.
  renderSummedTracker(toward) {
    const met = toward >= this.thresholdValue
    this.updateTracker(true, met, toward)
    if (this.hasPanelUnmetTarget) this.panelUnmetTarget.classList.toggle("d-none", met)
    if (this.hasPanelBadgeTarget) {
      this.panelBadgeTarget.classList.toggle("bg-success", met)
      this.panelBadgeTarget.classList.toggle("bg-warning", !met)
      this.panelBadgeTarget.classList.toggle("text-dark", !met)
    }
  }

  isVariable() {
    return this.hasVariantPricingValue && Object.keys(this.variantPricingValue).length > 0
  }

  // Called by the variant-selector (outlet) when the selection changes.
  applyVariant(variantId) {
    const p = variantId != null ? this.variantPricingValue[variantId] : null
    if (p) {
      this.lockedUnitCentsValue = p.locked_unit_cents
      this.unlockedUnitCentsValue = p.unlocked_unit_cents
      this.baseUnitCentsValue = p.base_unit_cents
      this.cartCurrentValue = p.cart_current
      if (p.cart_current_label) this.cartCurrentLabelValue = p.cart_current_label
      this.active = true
    } else {
      this.active = false
    }
    this.update()
  }

  update() {
    if (!this.active) {
      this.deactivate()
      return
    }

    const qty = Math.max(parseInt(this.quantityTarget.value, 10) || 0, 0)
    const hasCondition = this.conditionTypeValue !== "none" && this.thresholdValue > 0
    const contribution = this.conditionTypeValue === "amount" ? qty * this.baseUnitCentsValue : qty
    const projected = this.cartCurrentValue + contribution
    const met = !hasCondition || projected >= this.thresholdValue
    const unit = met ? this.unlockedUnitCentsValue : this.lockedUnitCentsValue

    if (this.hasTotalTarget) this.totalTarget.textContent = ` · ${this.formatPrice(unit * qty)}`
    if (this.hasDiscountNoteTarget) {
      const discounted = unit < this.baseUnitCentsValue
      this.discountNoteTarget.textContent = discounted
        ? this.discountAppliedTemplateValue.replace("%{discount}", this.discountLabelValue)
        : ""
    }

    this.updateHeader(unit)
    this.updateTracker(hasCondition, met, projected)

    // "Available discounts" panel hint reflects the live state.
    if (this.hasPanelUnmetTarget) this.panelUnmetTarget.classList.toggle("d-none", met)
    if (this.hasPanelBadgeTarget) {
      this.panelBadgeTarget.classList.toggle("bg-success", met)
      this.panelBadgeTarget.classList.toggle("bg-warning", !met)
      this.panelBadgeTarget.classList.toggle("text-dark", !met)
    }
  }

  // Variable product with no variant selected: hide the live bits and leave the
  // header/total to the variant-selector's range display.
  deactivate() {
    if (this.hasTrackerTarget) this.trackerTarget.classList.add("d-none")
    if (this.hasDiscountNoteTarget) this.discountNoteTarget.textContent = ""
    if (this.hasTotalTarget) this.totalTarget.textContent = ""
    if (this.hasPanelUnmetTarget) this.panelUnmetTarget.classList.remove("d-none")
  }

  updateHeader(unit) {
    if (!this.hasHeaderPriceTarget) return
    const discounted = unit < this.baseUnitCentsValue
    this.headerPriceTarget.textContent = this.formatPrice(unit)
    this.headerPriceTarget.classList.toggle("text-success", discounted)
    this.headerPriceTarget.classList.toggle("text-primary", !discounted)
    if (this.hasHeaderOriginalTarget) {
      this.headerOriginalTarget.textContent = this.formatPrice(this.baseUnitCentsValue)
      this.headerOriginalTarget.classList.toggle("d-none", !discounted)
    }
  }

  // One tracker that lives inside the discounts panel: while locked it shows
  // "X to go" + a partial amber bar; once unlocked it becomes the celebration
  // + a full green bar — so the goal and the payoff read in the same spot.
  updateTracker(hasCondition, met, projected) {
    if (!this.hasTrackerTarget) return
    this.trackerTarget.classList.toggle("d-none", !hasCondition)
    if (!hasCondition) return

    if (met) {
      // Unlocked by the cart vs. unlocked by the quantity now.
      const byCart = this.cartCurrentValue >= this.thresholdValue
      this.trackerTextTarget.textContent = byCart
        ? this.celebrationFromCartTemplateValue.replace("%{cart}", this.cartCurrentLabelValue)
        : this.celebrationDefaultValue
      this.trackerIconTarget.className = "fa-solid fa-circle-check me-1"
      this.setTrackerTone(true)
      this.progressBarTarget.style.width = "100%"
    } else {
      const remaining = this.thresholdValue - projected
      const remainingText = this.conditionTypeValue === "amount" ? this.formatPrice(remaining) : `${remaining}`
      this.trackerTextTarget.textContent = this.remainingTemplateValue
        .replace("%{remaining}", remainingText)
        .replace("%{discount}", this.discountLabelValue)
      this.trackerIconTarget.className = "fa-solid fa-bolt me-1"
      this.setTrackerTone(false)
      const pct = Math.min(Math.round((projected / this.thresholdValue) * 100), 100)
      this.progressBarTarget.style.width = `${pct}%`
    }
  }

  setTrackerTone(met) {
    this.trackerLineTarget.classList.toggle("text-success", met)
    this.trackerLineTarget.classList.toggle("text-warning", !met)
    this.progressBarTarget.classList.toggle("bg-success", met)
    this.progressBarTarget.classList.toggle("bg-warning", !met)
  }

  formatPrice(cents) {
    return `${this.currencySymbolValue}${(cents / 100).toFixed(2)}`
  }
}
