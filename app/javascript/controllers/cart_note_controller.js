import { Controller } from "@hotwired/stimulus"

// Per-line cart note: reveal an inline editor and auto-save on blur.
// The editor is a real form posting PATCH to the order item's #update, so
// saving re-renders the whole cart (totals, nudges) with no duplicated logic.
// Connects to data-controller="cart-note"
export default class extends Controller {
  static targets = ["toggle", "editor", "field"]

  open(event) {
    event.preventDefault()
    this.toggleTarget.classList.add("d-none")
    this.editorTarget.classList.remove("d-none")
    const field = this.fieldTarget
    field.focus()
    field.setSelectionRange(field.value.length, field.value.length)
  }

  // Blur commits the note. If unchanged, skip the round-trip and just collapse
  // back to the toggle so a stray focus doesn't reload the cart.
  save() {
    if (this.fieldTarget.value === (this.fieldTarget.dataset.original || "")) {
      this.editorTarget.classList.add("d-none")
      this.toggleTarget.classList.remove("d-none")
      return
    }
    this.editorTarget.requestSubmit()
  }
}
