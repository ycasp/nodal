import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

// Generic Stimulus controller that upgrades a <select> into a searchable Tom Select.
// Usage: add data-controller="tom-select" to any <select> element.
// Options are searched by their text content and any data-sku attribute.
export default class extends Controller {
  connect() {
    // Build options data with SKU before Tom Select initializes,
    // so the search index includes the SKU field from the start.
    const options = []
    const selected = this.element.value
    this.element.querySelectorAll("option").forEach(opt => {
      if (opt.value) {
        options.push({
          value: opt.value,
          text: opt.textContent,
          sku: opt.dataset.sku || ""
        })
      }
    })

    const isMultiple = this.element.multiple
    let items
    if (isMultiple) {
      items = Array.from(this.element.selectedOptions).map(opt => opt.value)
    } else {
      items = selected ? [selected] : []
    }

    this.select = new TomSelect(this.element, {
      options: options,
      items: items,
      plugins: isMultiple ? ['remove_button'] : [],
      valueField: "value",
      labelField: "text",
      searchField: ["text", "sku"],
      create: false,
      sortField: { field: "text", direction: "asc" },
      render: {
        option: function (data, escape) {
          const sku = data.sku ? `<span class="text-muted small"> (${escape(data.sku)})</span>` : ""
          return `<div>${escape(data.text)}${sku}</div>`
        },
        item: function (data, escape) {
          const sku = data.sku ? `<span class="text-muted small"> (${escape(data.sku)})</span>` : ""
          return `<div>${escape(data.text)}${sku}</div>`
        }
      }
    })
  }

  disconnect() {
    if (this.select) {
      this.select.destroy()
    }
  }
}
