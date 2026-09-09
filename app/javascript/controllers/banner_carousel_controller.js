import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="banner-carousel"
// Auto-advances through banner slides with crossfade
export default class extends Controller {
  static targets = ["slide", "indicator"]
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.currentIndex = 0
    // Set initial state via inline style (first slide visible)
    this.slideTargets.forEach((slide, i) => {
      slide.style.opacity = i === 0 ? "1" : "0"
    })
    this.updateIndicators()

    if (this.slideTargets.length > 1) {
      this.startAutoAdvance()
    }
  }

  disconnect() {
    this.stopAutoAdvance()
  }

  startAutoAdvance() {
    this.timer = setInterval(() => this.advance(), this.intervalValue)
  }

  stopAutoAdvance() {
    if (this.timer) clearInterval(this.timer)
  }

  resetAutoAdvance() {
    this.stopAutoAdvance()
    this.startAutoAdvance()
  }

  advance() {
    this.goTo((this.currentIndex + 1) % this.slideTargets.length)
  }

  next() {
    this.resetAutoAdvance()
    this.goTo((this.currentIndex + 1) % this.slideTargets.length)
  }

  prev() {
    this.resetAutoAdvance()
    this.goTo((this.currentIndex - 1 + this.slideTargets.length) % this.slideTargets.length)
  }

  goToSlide(event) {
    this.resetAutoAdvance()
    this.goTo(parseInt(event.currentTarget.dataset.index))
  }

  goTo(index) {
    this.slideTargets[this.currentIndex].style.opacity = "0"
    this.currentIndex = index
    this.slideTargets[this.currentIndex].style.opacity = "1"
    this.updateIndicators()
  }

  updateIndicators() {
    this.indicatorTargets.forEach((ind, i) => {
      ind.classList.toggle("home-banner__dot--active", i === this.currentIndex)
    })
  }
}
