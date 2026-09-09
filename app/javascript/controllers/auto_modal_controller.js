import { Controller } from "@hotwired/stimulus"

// Opens a Bootstrap modal as soon as the element with this controller
// connects to the DOM. Used together with a Turbo Stream response that
// injects a fully-rendered modal — the modal pops up the moment the
// response lands. The hidden.bs.modal listener cleans up the element so
// repeated triggers re-render fresh.
export default class extends Controller {
  connect() {
    if (typeof bootstrap === "undefined") return
    this.modal = bootstrap.Modal.getOrCreateInstance(this.element)
    this.modal.show()
    this.element.addEventListener("hidden.bs.modal", () => this.element.remove())
  }
}
