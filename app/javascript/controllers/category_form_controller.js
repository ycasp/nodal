import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="category-form"
export default class extends Controller {
  static targets = ["parentSelect", "depthWarning"]

  connect() {
    this.checkDepth()
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
}
