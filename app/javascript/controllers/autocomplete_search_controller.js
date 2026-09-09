import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  connect() {
    this._debounceTimer = null
    this._selectedIndex = -1
    this._outsideClick = (e) => {
      if (!this.element.contains(e.target)) this._hideResults()
    }
    document.addEventListener("click", this._outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
  }

  search() {
    clearTimeout(this._debounceTimer)
    this._selectedIndex = -1
    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this._hideResults()
      return
    }

    this._debounceTimer = setTimeout(() => this._fetchResults(query), 250)
  }

  navigate(e) {
    const items = this.resultsTarget.querySelectorAll("a")
    if (!items.length) return

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this._selectedIndex = Math.min(this._selectedIndex + 1, items.length - 1)
      this._highlightItem(items)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this._selectedIndex = Math.max(this._selectedIndex - 1, 0)
      this._highlightItem(items)
    } else if (e.key === "Enter" && this._selectedIndex >= 0) {
      e.preventDefault()
      items[this._selectedIndex].click()
    } else if (e.key === "Escape") {
      this._hideResults()
    }
  }

  async _fetchResults(query) {
    try {
      const url = `${this.urlValue}?q=${encodeURIComponent(query)}`
      const response = await fetch(url, { headers: { "Accept": "application/json" } })
      const data = await response.json()
      this._renderResults(data, query)
    } catch (e) {
      this._hideResults()
    }
  }

  _renderResults(data, query) {
    if (!data.categories?.length && !data.products?.length) {
      this._hideResults()
      return
    }

    let html = ""

    // "Search for" link
    html += `<a href="${data.search_url}" class="autocomplete-item autocomplete-search-all">
      <i class="fa-solid fa-magnifying-glass autocomplete-search-icon"></i>
      <span class="autocomplete-name">Pesquisar <strong>"${this._escapeHtml(query)}"</strong></span>
      <i class="fa-solid fa-arrow-right autocomplete-arrow"></i>
    </a>`

    // Categories
    if (data.categories?.length) {
      html += `<div class="autocomplete-section-label">Categorias</div>`
      data.categories.forEach((c) => {
        const display = c.path || c.name
        const name = this._highlight(display, query)
        html += `<a href="${c.url}" class="autocomplete-item">
          <i class="fa-solid fa-folder autocomplete-type-icon"></i>
          <span class="autocomplete-name">${name}</span>
        </a>`
      })
    }

    // Products
    if (data.products?.length) {
      html += `<div class="autocomplete-section-label">Produtos</div>`
      data.products.forEach((p) => {
        const name = this._highlight(p.name, query)
        const sku = p.sku ? `<span class="autocomplete-sku">${p.sku}</span>` : ""
        html += `<a href="${p.url}" class="autocomplete-item">
          <i class="fa-solid fa-box autocomplete-type-icon"></i>
          <span class="autocomplete-name">${name}</span>${sku}
        </a>`
      })
    }

    this.resultsTarget.innerHTML = html
    this.resultsTarget.classList.add("show")
  }

  _highlight(text, query) {
    const regex = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, "gi")
    return text.replace(regex, "<mark>$1</mark>")
  }

  _escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  _highlightItem(items) {
    items.forEach((item, i) => {
      item.classList.toggle("active", i === this._selectedIndex)
    })
  }

  _hideResults() {
    this.resultsTarget.classList.remove("show")
    this.resultsTarget.innerHTML = ""
    this._selectedIndex = -1
  }
}
