import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="hero-video"
// Handles crossfade between multiple background videos
export default class extends Controller {
  static targets = ["video"]

  connect() {
    this.currentIndex = 0
    this.transitionDuration = 8000 // 8 seconds per video

    // Start the first video
    if (this.videoTargets.length > 0) {
      this.videoTargets[0].classList.add("active")

      // Only start cycling if there are multiple videos
      if (this.videoTargets.length > 1) {
        this.startCycle()
      }
    }
  }

  disconnect() {
    if (this.cycleInterval) {
      clearInterval(this.cycleInterval)
    }
  }

  startCycle() {
    this.cycleInterval = setInterval(() => {
      this.nextVideo()
    }, this.transitionDuration)
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
