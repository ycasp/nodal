import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String, invert: { type: Boolean, default: false } }

  connect() {
    this.toggle()
  }

  toggle() {
    const target = document.querySelector(this.targetValue)
    if (target) {
      const show = this.invertValue ? !this.element.checked : this.element.checked
      target.style.display = show ? "" : "none"
    }
  }

  // Stimulus auto-wires change events on input elements
  change() {
    this.toggle()
  }
}
