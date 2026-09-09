import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchBar", "input"]

  toggle() {
    const bar = this.searchBarTarget
    bar.classList.toggle("collapsed")
    if (!bar.classList.contains("collapsed")) {
      this.inputTarget.focus()
    }
  }
}
