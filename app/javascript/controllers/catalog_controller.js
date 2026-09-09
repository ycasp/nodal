import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput", "selectionFrame",
    "categoryCount", "productCount",
    "settingsCategoryCount", "settingsProductCount",
    "hiddenFields",
    "functionalOnly", "premiumOnly"
  ]

  connect() {
    this.selectedCategories = new Set()
    this.selectedProducts = new Set()
    this.searchTimeout = null
    this.updateCounts()
    this.applyStyle()

    // Re-apply checkbox states after turbo frame loads
    document.addEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.handleFrameLoad)
    clearTimeout(this.searchTimeout)
  }

  handleFrameLoad = (event) => {
    if (event.target.id === "catalog_selection") {
      this.restoreSelections()
      // The input keeps its VALUE (it lives outside the frame), but Turbo's frame
      // navigation blurs the active element — restore focus so continuous typing
      // isn't interrupted. Only when the user is actually searching (has a value),
      // so we don't steal focus on the initial browse load.
      if (this.hasSearchInputTarget && this.searchInputTarget.value) {
        const input = this.searchInputTarget
        input.focus()
        input.setSelectionRange(input.value.length, input.value.length)
      }
    }
  }

  // Clear the (static) search box and reload the browse tree.
  clearSearch(event) {
    event.preventDefault()
    if (!this.hasSearchInputTarget) return
    const input = this.searchInputTarget
    input.value = ""
    const form = input.closest("form")
    if (form) form.requestSubmit()
    input.focus()
  }

  restoreSelections() {
    const frame = this.hasSelectionFrameTarget ? this.selectionFrameTarget : document.getElementById("catalog_selection")
    if (!frame) return

    frame.querySelectorAll(".product-checkbox").forEach(cb => {
      cb.checked = this.selectedProducts.has(cb.value)
    })
    frame.querySelectorAll(".category-checkbox").forEach(cb => {
      cb.checked = this.selectedCategories.has(cb.value)
    })
    this.updateCounts()
  }

  // Show only the options that apply to the chosen catalog style.
  applyStyle() {
    const checked = this.element.querySelector('input[name="catalog_style"]:checked')
    const premium = checked ? checked.value === "premium" : false
    this.premiumOnlyTargets.forEach(el => el.classList.toggle("d-none", !premium))
    this.functionalOnlyTargets.forEach(el => el.classList.toggle("d-none", premium))
  }

  // Debounced search — submits the form after 300ms
  debouncedSearch() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      const input = this.searchInputTarget
      const form = input.closest("form")
      if (form) form.requestSubmit()
    }, 300)
  }

  // Toggle category expand/collapse
  toggleExpand(event) {
    event.preventDefault()
    const container = event.currentTarget.closest("[data-catalog-role='category-row']")
    const children = container.querySelector(".category-children")
    const icon = event.currentTarget.querySelector("i")
    if (children) {
      children.classList.toggle("d-none")
      icon.classList.toggle("fa-chevron-right")
      icon.classList.toggle("fa-chevron-down")
    }
  }

  // Toggle category selection — cascades to all descendant categories and products
  toggleCategory(event) {
    const checkbox = event.currentTarget
    const container = checkbox.closest("[data-catalog-role='category-row']")
    const checked = checkbox.checked

    // Descendant category checkboxes include the container's own checkbox (harmless/idempotent)
    container.querySelectorAll(".category-checkbox").forEach(cb => {
      cb.checked = checked
      if (checked) this.selectedCategories.add(cb.value)
      else this.selectedCategories.delete(cb.value)
    })
    container.querySelectorAll(".product-checkbox").forEach(cb => {
      cb.checked = checked
      if (checked) this.selectedProducts.add(cb.value)
      else this.selectedProducts.delete(cb.value)
    })
    this.updateCounts()
  }

  // Toggle individual product
  toggleProduct(event) {
    const checkbox = event.currentTarget
    if (checkbox.checked) {
      this.selectedProducts.add(checkbox.value)
    } else {
      this.selectedProducts.delete(checkbox.value)
      // Uncheck parent category if a product is unchecked
      const categoryRow = checkbox.closest("[data-catalog-role='category-row']")
      if (categoryRow) {
        const catCheckbox = categoryRow.querySelector(".category-checkbox")
        if (catCheckbox) {
          catCheckbox.checked = false
          this.selectedCategories.delete(catCheckbox.value)
        }
      }
    }
    this.updateCounts()
  }

  // Select all visible on current page
  selectAllVisible(event) {
    event.preventDefault()
    const frame = document.getElementById("catalog_selection")
    if (!frame) return

    frame.querySelectorAll(".category-checkbox").forEach(cb => {
      cb.checked = true
      this.selectedCategories.add(cb.value)
    })
    frame.querySelectorAll(".product-checkbox").forEach(cb => {
      cb.checked = true
      this.selectedProducts.add(cb.value)
    })
    this.updateCounts()
  }

  // Deselect all (global)
  deselectAll(event) {
    event.preventDefault()
    this.selectedCategories.clear()
    this.selectedProducts.clear()
    document.querySelectorAll(".category-checkbox, .product-checkbox").forEach(cb => cb.checked = false)
    this.updateCounts()
  }

  updateCounts() {
    const catCount = this.selectedCategories.size
    const prodCount = this.selectedProducts.size

    if (this.hasCategoryCountTarget) this.categoryCountTarget.textContent = catCount
    if (this.hasProductCountTarget) this.productCountTarget.textContent = prodCount
    if (this.hasSettingsCategoryCountTarget) this.settingsCategoryCountTarget.textContent = catCount
    if (this.hasSettingsProductCountTarget) this.settingsProductCountTarget.textContent = prodCount

    if (this.hasHiddenFieldsTarget) {
      const container = this.hiddenFieldsTarget
      container.innerHTML = ""
      this.selectedProducts.forEach(id => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "product_ids[]"
        input.value = id
        container.appendChild(input)
      })
      this.selectedCategories.forEach(id => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "catalog_category_ids[]"
        input.value = id
        container.appendChild(input)
      })
    }
  }

  // Called when closing selection modal — go back to settings
  doneSelecting() {
    const selectionModal = bootstrap.Modal.getInstance(document.getElementById("catalogSelectionModal"))
    if (selectionModal) selectionModal.hide()
    setTimeout(() => {
      const settingsModal = bootstrap.Modal.getOrCreateInstance(document.getElementById("catalogModal"))
      settingsModal.show()
    }, 300)
  }

  // Open selection modal from settings modal
  openSelection(event) {
    event.preventDefault()
    const settingsModal = bootstrap.Modal.getInstance(document.getElementById("catalogModal"))
    if (settingsModal) settingsModal.hide()
    setTimeout(() => {
      // Lazy load: set src on first open
      if (this.hasSelectionFrameTarget && !this.selectionFrameTarget.src) {
        this.selectionFrameTarget.src = this.selectionFrameTarget.dataset.src
      }
      const selectionModal = bootstrap.Modal.getOrCreateInstance(document.getElementById("catalogSelectionModal"))
      selectionModal.show()
    }, 300)
  }
}
