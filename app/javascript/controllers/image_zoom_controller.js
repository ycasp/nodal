import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image"]

  connect() {
    this.scale = 1
    this.minScale = 1
    this.maxScale = 5
    this.panning = false
    this.pointX = 0
    this.pointY = 0
    this.startX = 0
    this.startY = 0

    this.imageTarget.style.transform = `translate(${this.pointX}px, ${this.pointY}px) scale(${this.scale})`
    this.imageTarget.style.transformOrigin = "center center"
    this.imageTarget.style.transition = "transform 0.1s ease-out"
  }

  wheel(event) {
    event.preventDefault()

    const delta = event.deltaY > 0 ? -0.3 : 0.3
    const newScale = Math.min(Math.max(this.minScale, this.scale + delta), this.maxScale)

    // If zooming out to minimum, reset position
    if (newScale === this.minScale) {
      this.pointX = 0
      this.pointY = 0
    }

    this.scale = newScale
    this.updateTransform()
  }

  mousedown(event) {
    if (this.scale > 1) {
      event.preventDefault()
      this.panning = true
      this.startX = event.clientX - this.pointX
      this.startY = event.clientY - this.pointY
      this.imageTarget.style.cursor = "grabbing"
      this.imageTarget.style.transition = "none"
    }
  }

  mousemove(event) {
    if (!this.panning) return
    event.preventDefault()

    this.pointX = event.clientX - this.startX
    this.pointY = event.clientY - this.startY
    this.updateTransform()
  }

  mouseup() {
    this.panning = false
    this.imageTarget.style.cursor = this.scale > 1 ? "grab" : "zoom-in"
    this.imageTarget.style.transition = "transform 0.1s ease-out"
  }

  mouseleave() {
    this.mouseup()
  }

  // Double-click to toggle zoom
  dblclick(event) {
    event.preventDefault()

    if (this.scale > 1) {
      this.scale = 1
      this.pointX = 0
      this.pointY = 0
    } else {
      this.scale = 2.5
    }
    this.updateTransform()
  }

  // Touch support
  touchstart(event) {
    if (event.touches.length === 1 && this.scale > 1) {
      this.panning = true
      this.startX = event.touches[0].clientX - this.pointX
      this.startY = event.touches[0].clientY - this.pointY
    }
  }

  touchmove(event) {
    if (!this.panning || event.touches.length !== 1) return
    event.preventDefault()

    this.pointX = event.touches[0].clientX - this.startX
    this.pointY = event.touches[0].clientY - this.startY
    this.updateTransform()
  }

  touchend() {
    this.panning = false
  }

  reset() {
    this.scale = 1
    this.pointX = 0
    this.pointY = 0
    this.updateTransform()
  }

  zoomIn() {
    this.scale = Math.min(this.scale + 0.5, this.maxScale)
    this.updateTransform()
  }

  zoomOut() {
    this.scale = Math.max(this.scale - 0.5, this.minScale)
    if (this.scale === this.minScale) {
      this.pointX = 0
      this.pointY = 0
    }
    this.updateTransform()
  }

  updateTransform() {
    this.imageTarget.style.transform = `translate(${this.pointX}px, ${this.pointY}px) scale(${this.scale})`
    this.imageTarget.style.cursor = this.scale > 1 ? "grab" : "zoom-in"
  }
}
