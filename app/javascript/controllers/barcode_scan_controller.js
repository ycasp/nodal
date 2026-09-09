import { Controller } from "@hotwired/stimulus"

// Scan-to-cart on the cart page. Keeps the scan input focused so a sales rep can
// scan one barcode after another without touching the screen: a Bluetooth
// scanner types "<code>\n" straight into the input, Enter submits the form, the
// cart re-renders (Turbo redirect), and connect() re-focuses for the next scan.
// Manual typing works the same way. No camera here — that's a later layer.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.focusInput()
  }

  focusInput() {
    if (!this.hasInputTarget) return
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  // Guard against a stray Enter submitting an empty code.
  submit(event) {
    if (this.hasInputTarget && this.inputTarget.value.trim() === "") {
      event.preventDefault()
    }
  }
}
