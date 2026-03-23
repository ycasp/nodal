import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon"]

  toggle() {
    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"

    // Update icon classes (Font Awesome)
    this.iconTarget.classList.toggle("fa-eye", !isPassword)
    this.iconTarget.classList.toggle("fa-eye-slash", isPassword)
  }
}
