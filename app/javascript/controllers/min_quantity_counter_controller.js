import { Controller } from "@hotwired/stimulus"

// Live, illustrative-only counter for combined-minimum products on the product
// page. Sums the quantity inputs + what's already in the cart and shows the
// progress toward the minimum. Never blocks adding to cart.
// Connects to data-controller="min-quantity-counter"
export default class extends Controller {
  static targets = ["input", "output"]
  static values = {
    min: Number,
    inCart: Number,
    label: String,
    below: String, // template with %{current} %{minimum} %{shortfall}
    met: String     // template with %{current} %{minimum}
  }

  connect() {
    this.update()
  }

  update() {
    const typed = this.inputTargets.reduce((sum, el) => {
      const n = parseInt(el.value, 10)
      return sum + (isNaN(n) || n < 0 ? 0 : n)
    }, 0)
    const current = this.inCartValue + typed
    const reached = current >= this.minValue
    const shortfall = Math.max(this.minValue - current, 0)

    const template = reached ? this.metValue : this.belowValue
    this.outputTarget.textContent = template
      .replace("%{current}", current)
      .replace("%{minimum}", this.labelValue)
      .replace("%{shortfall}", shortfall)

    this.outputTarget.classList.toggle("text-success", reached)
    this.outputTarget.classList.toggle("text-muted", !reached)
  }
}
