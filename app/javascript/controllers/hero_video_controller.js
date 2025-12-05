import { Controller } from "@hotwired/stimulus"

// Hero Video Controller
// Handles crossfade transitions between background videos like Shopify
export default class extends Controller {
  static targets = ["video"]

  connect() {
    this.currentIndex = 0
    this.transitionInterval = 8000 // 8 seconds per video

    // Start the transition loop once videos are ready
    if (this.videoTargets.length > 1) {
      this.startTransitions()
    }
  }

  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
    }
  }

  startTransitions() {
    // TODO(human): Implement the transition logic
    this.intervalId = setInterval(() => {
      this.nextVideo()
    }, this.transitionInterval)
  }

  nextVideo() {
    // Remove active class from current video
    this.videoTargets[this.currentIndex].classList.remove("active")

    // Move to next video (loop back to start)
    this.currentIndex = (this.currentIndex + 1) % this.videoTargets.length

    // Add active class to new video
    this.videoTargets[this.currentIndex].classList.add("active")
  }
}
