import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "toggleLink"]

  toggleAll(event) {
    event.preventDefault()
    const allChecked = this.checkboxTargets.every(cb => cb.checked)
    this.checkboxTargets.forEach(cb => cb.checked = !allChecked)
    this.updateToggleText()
  }

  checkboxChanged() {
    this.updateToggleText()
  }

  updateToggleText() {
    if (!this.hasToggleLinkTarget) return
    const allChecked = this.checkboxTargets.every(cb => cb.checked)
    this.toggleLinkTarget.textContent = allChecked
      ? this.toggleLinkTarget.dataset.deselectText || "Deselect all"
      : this.toggleLinkTarget.dataset.selectText || "Select all"
  }
}
