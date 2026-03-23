import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.toggleVisibility()
    window.addEventListener("scroll", this.toggleVisibility.bind(this))
  }

  disconnect() {
    window.removeEventListener("scroll", this.toggleVisibility.bind(this))
  }

  toggleVisibility() {
    if (window.scrollY > 300) {
      this.buttonTarget.classList.add("visible")
    } else {
      this.buttonTarget.classList.remove("visible")
    }
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}
