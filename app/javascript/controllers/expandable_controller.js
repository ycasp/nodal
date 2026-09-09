import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "toggle"]
  static values = { expanded: { type: Boolean, default: false } }

  toggle(event) {
    event.preventDefault()
    this.expandedValue = !this.expandedValue
    this.itemTargets.forEach(item => item.style.display = this.expandedValue ? "" : "none")
    this.toggleTarget.innerHTML = this.expandedValue ? this.collapseLabel : this.expandLabel
  }

  connect() {
    this.expandLabel = this.toggleTarget.innerHTML
    this.collapseLabel = this.toggleTarget.dataset.collapseLabel
  }
}
