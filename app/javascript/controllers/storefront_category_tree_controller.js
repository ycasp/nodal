import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="storefront-category-tree"
export default class extends Controller {
  static targets = ["item", "toggle", "children", "icon"]

  toggle(event) {
    const button = event.currentTarget
    const item = button.closest(".category-tree-item")
    const children = item.querySelector(".category-children")
    const icon = button.querySelector(".toggle-icon")

    if (children) {
      const isExpanded = !children.classList.contains("collapsed")

      if (isExpanded) {
        children.classList.add("collapsed")
        icon.classList.remove("fa-minus")
        icon.classList.add("fa-plus")
        button.setAttribute("aria-expanded", "false")
      } else {
        children.classList.remove("collapsed")
        icon.classList.remove("fa-plus")
        icon.classList.add("fa-minus")
        button.setAttribute("aria-expanded", "true")
      }
    }
  }
}
