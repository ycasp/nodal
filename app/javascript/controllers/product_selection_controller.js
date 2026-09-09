import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAll", "count", "bar", "catalogProductIds"]

  connect() {
    this.updateState()
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(cb => cb.checked = checked)
    this.updateState()
  }

  toggle() {
    this.updateState()
  }

  updateState() {
    const checked = this.checkboxTargets.filter(cb => cb.checked)
    const count = checked.length
    const total = this.checkboxTargets.length

    // Update select all
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = count === total && total > 0
      this.selectAllTarget.indeterminate = count > 0 && count < total
    }

    // Show/hide floating bar
    if (this.hasBarTarget) {
      this.barTarget.classList.toggle("d-none", count === 0)
    }

    // Update count
    if (this.hasCountTarget) {
      this.countTarget.textContent = count
    }

    // Update hidden fields in catalog modal
    if (this.hasCatalogProductIdsTarget) {
      const container = this.catalogProductIdsTarget
      container.innerHTML = ""
      checked.forEach(cb => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "product_ids[]"
        input.value = cb.value
        container.appendChild(input)
      })
    }
  }

  openCatalog(event) {
    event.preventDefault()
    const modal = document.getElementById("catalogModal")
    const bsModal = bootstrap.Modal.getOrCreateInstance(modal)
    bsModal.show()
  }
}
