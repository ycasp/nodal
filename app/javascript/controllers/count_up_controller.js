import { Controller } from "@hotwired/stimulus"

// Animates a number counting up from 0 to its final value.
// Usage: <span data-controller="count-up" data-count-up-value-value="30">30</span>
//
// Supports integers and simple "X%" patterns. For anything else
// (e.g. currency), wrap only the numeric part.
export default class extends Controller {
  static values = { value: String, duration: { type: Number, default: 800 } }

  connect() {
    const raw = this.valueValue || this.element.textContent.trim()
    const match = raw.match(/^([\d,.]+)\s*(%?)$/)
    if (!match) return

    const targetText = match[1]
    const suffix = match[2]
    const target = parseFloat(targetText.replace(/,/g, ""))
    if (isNaN(target) || target === 0) return

    const isInteger = !targetText.includes(".")
    const start = performance.now()
    const duration = this.durationValue

    const step = (now) => {
      const elapsed = now - start
      const progress = Math.min(elapsed / duration, 1)
      // Ease-out cubic
      const eased = 1 - Math.pow(1 - progress, 3)
      const current = eased * target

      this.element.textContent = (isInteger ? Math.round(current) : current.toFixed(1)) + suffix

      if (progress < 1) {
        requestAnimationFrame(step)
      }
    }

    this.element.textContent = "0" + suffix
    requestAnimationFrame(step)
  }
}
