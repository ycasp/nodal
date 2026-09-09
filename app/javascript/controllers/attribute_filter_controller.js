import { Controller } from "@hotwired/stimulus"

// Apply-on-close for the desktop storefront attribute filters.
//
// Each value is a checkbox inside a Bootstrap dropdown (data-bs-auto-close="outside",
// so the menu stays open while several values are ticked). Nothing navigates while
// ticking; when a dropdown closes, the surrounding form is submitted ONCE — but only
// if the selection actually changed while it was open, so closing an untouched
// dropdown never triggers a needless reload.
export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    this.snapshots = new WeakMap()
    this.onShown = (event) => this.snapshot(event.currentTarget)
    this.onHidden = (event) => this.applyIfChanged(event.currentTarget)

    this.dropdownTargets.forEach((dropdown) => {
      dropdown.addEventListener("shown.bs.dropdown", this.onShown)
      dropdown.addEventListener("hidden.bs.dropdown", this.onHidden)
    })
  }

  disconnect() {
    this.dropdownTargets.forEach((dropdown) => {
      dropdown.removeEventListener("shown.bs.dropdown", this.onShown)
      dropdown.removeEventListener("hidden.bs.dropdown", this.onHidden)
    })
  }

  snapshot(dropdown) {
    this.snapshots.set(dropdown, this.stateOf(dropdown))
  }

  applyIfChanged(dropdown) {
    const before = this.snapshots.get(dropdown)
    if (before === undefined || this.stateOf(dropdown) === before) return
    this.element.requestSubmit()
  }

  // A stable signature of which values are checked in this dropdown.
  stateOf(dropdown) {
    return Array.from(dropdown.querySelectorAll("input[type=checkbox]"))
      .filter((checkbox) => checkbox.checked)
      .map((checkbox) => checkbox.value)
      .sort()
      .join(",")
  }
}
