import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "content"]

  toggle() {
    this.contentTarget.style.display = this.triggerTarget.checked ? "" : "none"
  }
}
