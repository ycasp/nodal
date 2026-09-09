import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectedList", "emptyState", "search", "availableItem", "resultsFrame"]

  // Searching happens on the server now — the picker used to render every
  // product in the organisation and filter them here, which stopped working
  // once the catalog grew past a couple of thousand products.
  //
  // The frame is driven directly rather than by submitting a form: this card
  // lives inside the page's save form, and a nested form is invalid HTML — the
  // browser drops it, so a submit here saved the product on every keystroke.
  debouncedSearch() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.search(), 300)
  }

  search() {
    const frame = this.resultsFrameTarget
    const url = new URL(frame.dataset.searchUrl, window.location.origin)
    const query = this.searchTarget.value.trim()

    if (query) url.searchParams.set("query", query)

    // Assigning the same src is a no-op in Turbo, so reload explicitly when the
    // query has not actually changed (a trailing space, say).
    if (frame.src === url.toString()) {
      frame.reload()
    } else {
      frame.src = url.toString()
    }
  }

  // The input sits inside the page's save form, where Enter would submit it.
  preventSubmit(event) {
    event.preventDefault()
    this.search()
  }

  // Results arrive from the server knowing nothing about what has been picked
  // in the browser but not yet saved, so hide those rows after every reload.
  syncAvailable() {
    this.availableItemTargets.forEach(item => {
      item.classList.toggle("d-none", this.isSelected(item.dataset.productId))
    })
  }

  add(event) {
    event.preventDefault()
    const button = event.currentTarget
    const { productId, productName, productCategory, productImage } = button.dataset

    if (this.isSelected(productId)) return

    this.selectedListTarget.insertAdjacentHTML(
      "beforeend",
      this.selectedItemHtml(productId, productName, productCategory, productImage)
    )

    this.hideAvailable(productId, true)
    this.emptyStateTarget.classList.add("visually-hidden")
  }

  remove(event) {
    event.preventDefault()
    const button = event.currentTarget
    const productId = button.dataset.productId
    const itemElement = button.closest("[data-sortable-id]")

    if (itemElement) itemElement.remove()

    this.hideAvailable(productId, false)

    const remainingItems = this.selectedListTarget.querySelectorAll("[data-sortable-id]")
    if (remainingItems.length === 0) {
      this.emptyStateTarget.classList.remove("visually-hidden")
    }
  }

  isSelected(productId) {
    return Boolean(this.selectedListTarget.querySelector(`[data-sortable-id="${productId}"]`))
  }

  hideAvailable(productId, hidden) {
    const availableItem = this.availableItemTargets.find(item => item.dataset.productId === productId)
    if (availableItem) availableItem.classList.toggle("d-none", hidden)
  }

  // Product names come from the ERP and land in the back office unfiltered, so
  // they are escaped rather than dropped into the markup as-is.
  escape(value) {
    const div = document.createElement("div")
    div.textContent = value ?? ""
    return div.innerHTML
  }

  selectedItemHtml(productId, productName, productCategory, productImage) {
    const id = this.escape(productId)
    const imageHtml = productImage
      ? `<img src="${this.escape(productImage)}" style="width: 40px; height: 40px; object-fit: cover; border-radius: 4px;" loading="lazy">`
      : `<div class="bg-secondary d-flex align-items-center justify-content-center" style="width: 40px; height: 40px; border-radius: 4px;">
           <i class="fa-solid fa-image text-white"></i>
         </div>`

    return `
      <div class="d-flex align-items-center gap-3 p-2 mb-2 bg-light rounded" data-sortable-id="${id}">
        <i class="fa-solid fa-grip-vertical text-muted handle" style="cursor: grab;"></i>
        <input type="hidden" name="related_product_ids[]" value="${id}">
        ${imageHtml}
        <div class="flex-grow-1">
          <strong>${this.escape(productName)}</strong>
          <small class="text-muted d-block">${this.escape(productCategory)}</small>
        </div>
        <button type="button" class="btn btn-sm btn-outline-danger" data-action="click->related-products#remove" data-product-id="${id}">
          <i class="fa-solid fa-times"></i>
        </button>
      </div>
    `
  }
}
