import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.changed = false
    this.boundInputHandler = () => { this.changed = true }
    this.boundBeforeUnload = (e) => this.handleBeforeUnload(e)
    this.boundTurboBeforeVisit = (e) => this.handleTurboBeforeVisit(e)
    this.boundSubmit = () => { this.changed = false }

    this.element.addEventListener("input", this.boundInputHandler)
    this.element.addEventListener("change", this.boundInputHandler)
    this.element.addEventListener("submit", this.boundSubmit)
    window.addEventListener("beforeunload", this.boundBeforeUnload)
    document.addEventListener("turbo:before-visit", this.boundTurboBeforeVisit)
  }

  disconnect() {
    this.element.removeEventListener("input", this.boundInputHandler)
    this.element.removeEventListener("change", this.boundInputHandler)
    this.element.removeEventListener("submit", this.boundSubmit)
    window.removeEventListener("beforeunload", this.boundBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.boundTurboBeforeVisit)
  }

  handleBeforeUnload(event) {
    if (this.changed) {
      event.preventDefault()
      event.returnValue = ""
    }
  }

  handleTurboBeforeVisit(event) {
    if (this.changed) {
      if (!confirm(this.element.dataset.unsavedChangesMessage || "You have unsaved changes. Are you sure you want to leave?")) {
        event.preventDefault()
      }
    }
  }
}
