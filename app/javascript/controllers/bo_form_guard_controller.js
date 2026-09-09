import { Controller } from "@hotwired/stimulus"

// Automatically guards all forms within the BO layout against unsaved changes.
// Attach to a parent element (e.g., <main>) — it watches all descendant forms.
export default class extends Controller {
  connect() {
    this.dirty = false
    this.submitting = false

    this.onInput = () => { this.dirty = true }
    this.onSubmit = () => { this.submitting = true; this.dirty = false }
    this.onBeforeUnload = (e) => {
      if (this.dirty) {
        e.preventDefault()
        e.returnValue = ""
      }
    }
    this.onTurboBeforeVisit = (e) => {
      if (this.dirty && !this.submitting) {
        const message = this.element.dataset.boFormGuardMessage || "Tem alterações por guardar. Tem a certeza que quer sair?"
        if (!confirm(message)) {
          e.preventDefault()
        } else {
          this.dirty = false
        }
      }
    }
    // Allow any child controller to dismiss the guard before a dynamic submit
    this.onDismiss = () => { this.dirty = false; this.submitting = true }
    // Reset after Turbo navigation completes
    this.onTurboLoad = () => { this.dirty = false; this.submitting = false }

    this.element.addEventListener("input", this.onInput)
    this.element.addEventListener("change", this.onInput)
    this.element.addEventListener("submit", this.onSubmit)
    this.element.addEventListener("form-guard:dismiss", this.onDismiss)
    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("turbo:before-visit", this.onTurboBeforeVisit)
    document.addEventListener("turbo:load", this.onTurboLoad)
  }

  disconnect() {
    this.element.removeEventListener("input", this.onInput)
    this.element.removeEventListener("change", this.onInput)
    this.element.removeEventListener("submit", this.onSubmit)
    this.element.removeEventListener("form-guard:dismiss", this.onDismiss)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.onTurboBeforeVisit)
    document.removeEventListener("turbo:load", this.onTurboLoad)
  }
}
