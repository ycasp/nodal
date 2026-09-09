import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="storefront-category-tree"
export default class extends Controller {
  static targets = ["item", "children", "icon", "parentLink"]

  toggleFromLink(event) {
    const link = event.currentTarget
    const item = link.closest(".category-list-item")
    const children = item.querySelector(":scope > .category-children")

    if (!children) return

    const isExpanded = !children.classList.contains("collapsed")

    // If already on this category (link is active), just toggle children
    if (link.classList.contains("active")) {
      event.preventDefault()
      this._toggle(children, item)
      return
    }

    // If children are collapsed, expand them but also follow the link
    if (!isExpanded) {
      this._toggle(children, item)
    }
    // Let the link navigate normally
  }

  _toggle(children, item) {
    const icon = item.querySelector(":scope > .category-link .category-chevron")
    const isExpanded = !children.classList.contains("collapsed")

    if (isExpanded) {
      children.classList.add("collapsed")
      if (icon) icon.classList.remove("expanded")
    } else {
      children.classList.remove("collapsed")
      if (icon) icon.classList.add("expanded")
    }
  }
}
