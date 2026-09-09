import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.element.classList.toggle("active")
  }

  // Close menu when clicking a nav link
  close() {
    this.element.classList.remove("active")
  }
}
