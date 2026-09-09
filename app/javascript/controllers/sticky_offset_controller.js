import { Controller } from "@hotwired/stimulus"

// Publishes the sticky header's real height as the CSS variable
// --storefront-header-height, so sticky elements below it (e.g. the mobile
// product toolbar) offset correctly regardless of logo size or banners.
export default class extends Controller {
  connect() {
    this.update = this.update.bind(this)
    this.update()
    window.addEventListener("resize", this.update, { passive: true })
    // Re-measure once the logo image has loaded (offsetHeight can change).
    this.element.querySelectorAll("img").forEach((img) => {
      if (!img.complete) img.addEventListener("load", this.update, { once: true })
    })
    if (window.ResizeObserver) {
      this.observer = new ResizeObserver(this.update)
      this.observer.observe(this.element)
    }
  }

  disconnect() {
    window.removeEventListener("resize", this.update)
    this.observer?.disconnect()
    document.documentElement.style.removeProperty("--storefront-header-height")
  }

  update() {
    const height = this.element.offsetHeight
    if (height > 0) {
      document.documentElement.style.setProperty("--storefront-header-height", `${height}px`)
    }
  }
}
