import { Controller } from "@hotwired/stimulus"

// Toggles between product and category selects for discount targeting.
// Shows/hides the appropriate select and clears the hidden one.
export default class extends Controller {
  static targets = ["productWrapper", "categoryWrapper", "productSelect", "categorySelect"]
  static values = { url: String }

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.element.querySelector("input[name='target_type']:checked")?.value
    if (selected === "category") {
      this.productWrapperTarget.classList.add("d-none")
      this.categoryWrapperTarget.classList.remove("d-none")
      // Clear product select
      this.clearSelect(this.productSelectTarget)
    } else {
      this.productWrapperTarget.classList.remove("d-none")
      this.categoryWrapperTarget.classList.add("d-none")
      // Clear category select
      this.clearSelect(this.categorySelectTarget)
    }
  }

  // Reload variant overrides when category changes
  categoryChanged(event) {
    const categoryId = event.target.value
    const frame = document.getElementById("variant-overrides")
    if (!frame) return

    if (categoryId) {
      const newSrc = `${this.urlValue}?category_id=${categoryId}`
      if (frame.src === newSrc) {
        frame.removeAttribute("src")
      }
      frame.src = newSrc
    } else {
      frame.removeAttribute("src")
      frame.innerHTML = ""
    }
  }

  clearSelect(selectEl) {
    // If Tom Select is managing this element, use its API
    if (selectEl.tomselect) {
      selectEl.tomselect.clear()
    } else {
      selectEl.value = ""
    }
  }
}
