import { Controller } from "@hotwired/stimulus"

// Reloads the page after `intervalValue` ms. Used by the Quick Access
// page while PDFs are being generated in the background — refreshes
// every few seconds until the view stops rendering this controller
// (i.e. once all attachments are present).
export default class extends Controller {
  static values = { interval: { type: Number, default: 3000 } }

  connect() {
    this.timer = setTimeout(() => { window.location.reload() }, this.intervalValue)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }
}
