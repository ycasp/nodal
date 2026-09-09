import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image"]

  open(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.lightboxUrl
    this.imageTarget.src = url
    this.modalTarget.classList.add("show")
    this.modalTarget.style.display = "block"
    document.body.classList.add("modal-open")
  }

  close(event) {
    if (event.target === this.modalTarget || event.currentTarget.dataset.action?.includes("close")) {
      this.modalTarget.classList.remove("show")
      this.modalTarget.style.display = "none"
      document.body.classList.remove("modal-open")
      this.imageTarget.src = ""
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.modalTarget.classList.remove("show")
      this.modalTarget.style.display = "none"
      document.body.classList.remove("modal-open")
      this.imageTarget.src = ""
    }
  }
}
