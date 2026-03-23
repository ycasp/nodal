import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectedList", "emptyState", "search", "availableItem"]

  add(event) {
    event.preventDefault()
    const button = event.currentTarget
    const productId = button.dataset.productId
    const productName = button.dataset.productName
    const productCategory = button.dataset.productCategory
    const productImage = button.dataset.productImage

    // Create the selected item HTML
    const itemHtml = this.createSelectedItemHtml(productId, productName, productCategory, productImage)

    // Add to selected list
    this.selectedListTarget.insertAdjacentHTML('beforeend', itemHtml)

    // Hide the available item
    const availableItem = this.availableItemTargets.find(item => item.dataset.productId === productId)
    if (availableItem) {
      availableItem.classList.add('d-none')
    }

    // Hide empty state
    this.emptyStateTarget.classList.add('visually-hidden')
  }

  remove(event) {
    event.preventDefault()
    const button = event.currentTarget
    const productId = button.dataset.productId
    const itemElement = button.closest('[data-sortable-id]')

    // Remove from selected list
    if (itemElement) {
      itemElement.remove()
    }

    // Show the available item again
    const availableItem = this.availableItemTargets.find(item => item.dataset.productId === productId)
    if (availableItem) {
      availableItem.classList.remove('d-none')
    }

    // Show empty state if no items left
    const remainingItems = this.selectedListTarget.querySelectorAll('[data-sortable-id]')
    if (remainingItems.length === 0) {
      this.emptyStateTarget.classList.remove('visually-hidden')
    }
  }

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim()

    this.availableItemTargets.forEach(item => {
      const productName = item.dataset.productName || ''
      const productId = item.dataset.productId
      const isSelected = this.selectedListTarget.querySelector(`[data-sortable-id="${productId}"]`)

      // If already selected, always keep hidden
      if (isSelected) {
        item.classList.add('d-none')
        return
      }

      // Show/hide based on search query
      if (query === '' || productName.includes(query)) {
        item.classList.remove('d-none')
      } else {
        item.classList.add('d-none')
      }
    })
  }

  createSelectedItemHtml(productId, productName, productCategory, productImage) {
    const imageHtml = productImage
      ? `<img src="${productImage}" style="width: 40px; height: 40px; object-fit: cover; border-radius: 4px;">`
      : `<div class="bg-secondary d-flex align-items-center justify-content-center" style="width: 40px; height: 40px; border-radius: 4px;">
           <i class="fa-solid fa-image text-white"></i>
         </div>`

    return `
      <div class="d-flex align-items-center gap-3 p-2 mb-2 bg-light rounded" data-sortable-id="${productId}">
        <i class="fa-solid fa-grip-vertical text-muted handle" style="cursor: grab;"></i>
        <input type="hidden" name="related_product_ids[]" value="${productId}">
        ${imageHtml}
        <div class="flex-grow-1">
          <strong>${productName}</strong>
          <small class="text-muted d-block">${productCategory || ''}</small>
        </div>
        <button type="button" class="btn btn-sm btn-outline-danger" data-action="click->related-products#remove" data-product-id="${productId}">
          <i class="fa-solid fa-times"></i>
        </button>
      </div>
    `
  }
}
