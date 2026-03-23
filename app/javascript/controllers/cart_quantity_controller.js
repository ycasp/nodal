import { Controller } from "@hotwired/stimulus"

// Touch-friendly quantity controls for mobile cart
// Connects to data-controller="cart-quantity"
export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    this.minQuantity = parseInt(this.inputTarget.min) || 1
  }

  increment(event) {
    event.preventDefault()
    const currentValue = parseInt(this.inputTarget.value) || this.minQuantity
    this.inputTarget.value = currentValue + 1
    this.submit()
  }

  decrement(event) {
    event.preventDefault()
    const currentValue = parseInt(this.inputTarget.value) || this.minQuantity
    if (currentValue > this.minQuantity) {
      this.inputTarget.value = currentValue - 1
      this.submit()
    }
  }

  submit() {
    // Submit the form after a short delay to allow for rapid clicks
    clearTimeout(this.submitTimeout)
    this.submitTimeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 300)
  }
}
