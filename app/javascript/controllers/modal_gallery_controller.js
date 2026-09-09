import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "counter", "thumbnail"]
  static values = { photos: Array }

  connect() {
    this.currentIndex = 0
    this.updateCounter()
  }

  next() {
    if (this.photosValue.length === 0) return
    this.currentIndex = (this.currentIndex + 1) % this.photosValue.length
    this.showCurrent()
  }

  prev() {
    if (this.photosValue.length === 0) return
    this.currentIndex = (this.currentIndex - 1 + this.photosValue.length) % this.photosValue.length
    this.showCurrent()
  }

  goTo(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    if (isNaN(index)) return
    this.currentIndex = index
    this.showCurrent()
  }

  keydown(event) {
    const modal = this.element
    if (!modal.classList.contains("show")) return

    if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.prev()
    } else if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    }
  }

  showCurrent() {
    if (this.hasImageTarget) {
      this.imageTarget.style.opacity = "0"
      setTimeout(() => {
        this.imageTarget.src = this.photosValue[this.currentIndex]
        this.imageTarget.style.opacity = "1"
      }, 150)
    }
    this.updateCounter()
    this.updateThumbnails()
  }

  updateCounter() {
    if (this.hasCounterTarget && this.photosValue.length > 1) {
      this.counterTarget.textContent = `${this.currentIndex + 1} / ${this.photosValue.length}`
    }
  }

  updateThumbnails() {
    this.thumbnailTargets.forEach((thumb, i) => {
      if (i === this.currentIndex) {
        thumb.style.borderColor = "#0d6efd"
      } else {
        thumb.style.borderColor = "#dee2e6"
      }
    })
  }
}
