import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="category-form"
export default class extends Controller {
  static targets = [
    "parentSelect", "depthWarning",
    "colorPicker", "colorText", "swatch", "navBold", "navItalic", "preview"
  ]

  connect() {
    this.checkDepth()
    this.updatePreview()
  }

  checkDepth() {
    if (!this.hasParentSelectTarget || !this.hasDepthWarningTarget) return

    const selectedOption = this.parentSelectTarget.selectedOptions[0]
    if (!selectedOption || !selectedOption.value) {
      this.depthWarningTarget.classList.add("d-none")
      return
    }

    // Count depth from the parent's full path (number of " > " separators + 1)
    const fullPath = selectedOption.text
    const depth = (fullPath.match(/ > /g) || []).length + 1

    // Show warning if depth would be 4 or more (3 ancestors + new category = depth 4)
    if (depth >= 3) {
      this.depthWarningTarget.classList.remove("d-none")
    } else {
      this.depthWarningTarget.classList.add("d-none")
    }
  }

  // --- Colour ---------------------------------------------------------------
  // Only colorText carries the category[color] name. The picker and the
  // swatches are input aids that write into it; when both inputs shared the
  // name, the empty text field won on submit and wiped the chosen colour.

  pickColor(event) {
    this.#setColor(event.currentTarget.dataset.color)
  }

  syncFromPicker() {
    this.#setColor(this.colorPickerTarget.value)
  }

  syncFromText() {
    const value = this.colorTextTarget.value.trim()
    if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(value)) {
      this.colorPickerTarget.value = value
    }
    this.#markSelectedSwatch(value)
    this.updatePreview()
  }

  clearColor() {
    this.colorTextTarget.value = ""
    this.colorPickerTarget.value = "#6c757d"
    this.#markSelectedSwatch("")
    this.updatePreview()
  }

  #setColor(value) {
    this.colorTextTarget.value = value
    this.colorPickerTarget.value = value
    this.#markSelectedSwatch(value)
    this.updatePreview()
  }

  #markSelectedSwatch(value) {
    const normalized = (value || "").toLowerCase()
    this.swatchTargets.forEach((swatch) => {
      swatch.classList.toggle("selected", swatch.dataset.color.toLowerCase() === normalized)
    })
  }

  // --- Preview --------------------------------------------------------------

  updatePreview() {
    if (!this.hasPreviewTarget) return

    const color = this.hasColorTextTarget ? this.colorTextTarget.value.trim() : ""
    this.previewTarget.style.color = color || ""
    this.previewTarget.style.fontWeight =
      this.hasNavBoldTarget && this.navBoldTarget.checked ? "600" : ""
    this.previewTarget.style.fontStyle =
      this.hasNavItalicTarget && this.navItalicTarget.checked ? "italic" : ""
  }
}
