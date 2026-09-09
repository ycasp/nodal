import { Controller } from "@hotwired/stimulus"

// Copies data-copy-to-clipboard-text-value into the clipboard when the
// element is clicked. Swaps the inner HTML with the "copied" state for
// ~1.5s so the merchant sees feedback. Used by the Quick Access share
// section on the BO QR page.
export default class extends Controller {
  static values = {
    text: String,
    copiedLabel: { type: String, default: "Copiado!" }
  }

  static targets = ["label"]

  copy(event) {
    event.preventDefault()
    if (!this.textValue) return

    navigator.clipboard.writeText(this.textValue).then(() => {
      this.flashCopied()
    }).catch(() => {
      // Fallback for older browsers / non-secure contexts
      const ta = document.createElement("textarea")
      ta.value = this.textValue
      ta.style.position = "fixed"
      ta.style.opacity = "0"
      document.body.appendChild(ta)
      ta.select()
      try { document.execCommand("copy") } catch (_) {}
      document.body.removeChild(ta)
      this.flashCopied()
    })
  }

  flashCopied() {
    if (!this.hasLabelTarget) return
    const original = this.labelTarget.innerHTML
    this.labelTarget.textContent = this.copiedLabelValue
    setTimeout(() => { this.labelTarget.innerHTML = original }, 1500)
  }
}
