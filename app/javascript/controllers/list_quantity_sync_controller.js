import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity"]

  sync() {
    // Find the quantity input from the Add to Cart form on the page
    const quantityInput = document.querySelector('input[name="order_item[quantity]"]')
    if (quantityInput && this.hasQuantityTarget) {
      const value = parseInt(quantityInput.value) || 1
      this.quantityTargets.forEach(hidden => hidden.value = value)
    }
  }
}
