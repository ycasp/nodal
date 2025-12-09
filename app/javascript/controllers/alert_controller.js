import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 3000 }
  }

  connect() {
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.durationValue)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  dismiss() {
    // Use Bootstrap's global object (importmap doesn't support named exports)
    const alert = window.bootstrap.Alert.getOrCreateInstance(this.element)
    alert.close()
  }
}
