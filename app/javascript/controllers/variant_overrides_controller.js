import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  change(event) {
    const productId = event.target.value
    const frame = document.getElementById("variant-overrides")
    if (!frame) return

    if (productId) {
      const newSrc = `${this.urlValue}?product_id=${productId}`
      if (frame.src === newSrc) {
        frame.removeAttribute("src")
      }
      frame.src = newSrc
    } else {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    }
  }
}
