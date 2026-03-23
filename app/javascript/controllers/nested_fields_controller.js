import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "field", "destroy", "empty"]

  add() {
    const content = this.templateTarget.innerHTML.replace(
      /NEW_RECORD/g,
      new Date().getTime()
    )

    this.containerTarget.insertAdjacentHTML("afterbegin", content)
    this.updateEmptyState()
  }

  remove(event) {
    const field = event.target.closest("[data-nested-fields-target='field']")

    if (field) {
      // Find the _destroy hidden field within this nested field
      const destroyField = field.querySelector("[data-nested-fields-target='destroy']")

      if (destroyField && destroyField.name.includes("[id]") === false) {
        // This is a persisted record - mark for destruction
        destroyField.value = "1"
        field.style.display = "none"
      } else {
        // This is a new record - just remove from DOM
        field.remove()
      }

      this.updateEmptyState()
    }
  }

  updateEmptyState() {
    if (!this.hasEmptyTarget) return

    const visibleFields = this.fieldTargets.filter(f => f.style.display !== "none")
    this.emptyTarget.style.display = visibleFields.length === 0 ? "block" : "none"
  }
}
