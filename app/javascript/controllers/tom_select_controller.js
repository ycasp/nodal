import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

// Generic Stimulus controller that upgrades a <select> into a searchable Tom Select.
// Usage: add data-controller="tom-select" to any <select> element.
// Options are searched by their text content and any data-sku attribute.
//
// With data-tom-select-url-value set, the options come from that URL as the user
// types instead of being embedded in the page. The order editor needs this: the
// catalog is 4234 sellable variants, and a <select> carrying all of them in
// every row is what made picking a line by SKU impractical in the first place.
export default class extends Controller {
  static values = { url: String, minChars: { type: Number, default: 2 } }

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

    const config = {
      options: options,
      items: items,
      plugins: isMultiple ? ['remove_button'] : [],
      valueField: "value",
      labelField: "text",
      searchField: ["text", "sku"],
      create: false,
      sortField: { field: "text", direction: "asc" },
      render: {
        // stock and warning are optional: only the remote sources that send
        // them (the order line picker) render the extra state.
        option: function (data, escape) {
          const sku = data.sku ? `<span class="text-muted small"> (${escape(data.sku)})</span>` : ""
          const stock = data.stock ? `<span class="text-muted small"> · ${escape(data.stock)}</span>` : ""
          const warning = data.warning ? `<span class="badge text-bg-warning ms-2">${escape(data.warning)}</span>` : ""
          return `<div>${escape(data.text)}${sku}${stock}${warning}</div>`
        },
        item: function (data, escape) {
          const sku = data.sku ? `<span class="text-muted small"> (${escape(data.sku)})</span>` : ""
          const warning = data.warning ? `<span class="badge text-bg-warning ms-2">${escape(data.warning)}</span>` : ""
          return `<div>${escape(data.text)}${sku}${warning}</div>`
        }
      }
    }

    if (this.hasUrlValue) {
      // Nothing is worth showing until the user has typed something specific:
      // an unfiltered list here would be the whole catalog again.
      config.shouldLoad = query => query.length >= this.minCharsValue
      config.load = (query, callback) => {
        const url = new URL(this.urlValue, window.location.origin)
        url.searchParams.set("query", query)

        fetch(url, { headers: { Accept: "application/json" } })
          .then(response => response.json())
          .then(callback)
          .catch(() => callback())
      }
    }

    this.select = new TomSelect(this.element, config)
  }

  disconnect() {
    if (this.select) {
      this.select.destroy()
    }
  }
}
