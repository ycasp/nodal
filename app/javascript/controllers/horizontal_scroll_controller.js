import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="horizontal-scroll"
// Provides left/right arrow buttons for horizontal scrollable containers
export default class extends Controller {
  static targets = ["container", "leftBtn", "rightBtn"]

  connect() {
    this.updateButtons()
    this.containerTarget.addEventListener("scroll", () => this.updateButtons())
    // Re-check after images load
    this.containerTarget.addEventListener("load", () => this.updateButtons(), true)
    // Auto-scroll active item into view (for category chips etc.)
    const active = this.containerTarget.querySelector(".active")
    if (active) {
      requestAnimationFrame(() => {
        active.scrollIntoView({ inline: "center", behavior: "smooth", block: "nearest" })
      })
    }
  }

  scrollLeft() {
    const scrollAmount = this.containerTarget.clientWidth * 0.75
    this.containerTarget.scrollBy({ left: -scrollAmount, behavior: "smooth" })
  }

  scrollRight() {
    const scrollAmount = this.containerTarget.clientWidth * 0.75
    this.containerTarget.scrollBy({ left: scrollAmount, behavior: "smooth" })
  }

  updateButtons() {
    const { scrollLeft, scrollWidth, clientWidth } = this.containerTarget
    if (this.hasLeftBtnTarget) {
      this.leftBtnTarget.style.display = scrollLeft > 5 ? "" : "none"
    }
    if (this.hasRightBtnTarget) {
      this.rightBtnTarget.style.display = scrollLeft + clientWidth < scrollWidth - 5 ? "" : "none"
    }
  }
}
