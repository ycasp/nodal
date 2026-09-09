import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["comboInput", "hiddenInput", "comboWrapper", "dropdown", "createItem", "createLabel", "inputWrapper", "input", "createBtn", "createName"]
  static values = { attributeId: Number }

  connect() {
    this._highlightIndex = -1
    this._allItems = [...this.dropdownTarget.querySelectorAll(".dropdown-item[data-id]")].map(el => ({
      el: el.closest("li"),
      id: el.dataset.id,
      value: el.dataset.value,
      text: el.dataset.value.toLowerCase()
    }))

    // Close dropdown on outside click
    this._outsideClick = (e) => {
      if (!this.comboWrapperTarget.contains(e.target)) this.closeDropdown()
    }
    document.addEventListener("click", this._outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
  }

  openDropdown() {
    this.dropdownTarget.style.display = "block"
    this._filter(this.comboInputTarget.value)
  }

  closeDropdown() {
    this.dropdownTarget.style.display = "none"
    this._highlightIndex = -1
    this._clearHighlight()
  }

  onType() {
    const query = this.comboInputTarget.value
    this.dropdownTarget.style.display = "block"
    this._filter(query)
    this._highlightIndex = -1
    this._clearHighlight()

    // Update hidden input
    const match = this._allItems.find(i => i.text === query.toLowerCase().trim())
    this.hiddenInputTarget.value = match ? match.id : ""
  }

  onKeydown(event) {
    const visible = this._visibleItems()
    if (!visible.length) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this._highlightIndex = Math.min(this._highlightIndex + 1, visible.length - 1)
      this._applyHighlight(visible)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this._highlightIndex = Math.max(this._highlightIndex - 1, 0)
      this._applyHighlight(visible)
    } else if (event.key === "Enter") {
      event.preventDefault()
      if (this._highlightIndex >= 0 && this._highlightIndex < visible.length) {
        const item = visible[this._highlightIndex]
        this._select(item.id, item.value)
      }
    } else if (event.key === "Escape") {
      this.closeDropdown()
    }
  }

  selectOption(event) {
    event.preventDefault()
    const el = event.currentTarget
    this._select(el.dataset.id, el.dataset.value)
  }

  showCreateInput(event) {
    event.preventDefault()
    this.closeDropdown()
    this.inputWrapperTarget.style.display = ""
    this.inputTarget.value = this.comboInputTarget.value.trim().replace(/,/g, ".")
    this.inputTarget.focus()
    this.onInput()
  }

  onInput() {
    const val = this.inputTarget.value.trim().replace(/,/g, ".")
    if (val) {
      this.createBtnTarget.style.display = ""
      this.createNameTarget.textContent = val
    } else {
      this.createBtnTarget.style.display = "none"
    }
  }

  async create(event) {
    event.preventDefault()
    const newValue = this.inputTarget.value.trim().replace(/,/g, ".")
    if (!newValue) return

    const btn = this.createBtnTarget
    btn.disabled = true

    try {
      const orgSlug = window.location.pathname.split("/")[1]
      const csrfToken = document.querySelector("meta[name='csrf-token']").content
      const response = await fetch(`/${orgSlug}/bo/product_attributes/${this.attributeIdValue}/product_attribute_values`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ value: newValue })
      })

      if (response.ok) {
        const data = await response.json()

        // Add to dropdown list
        const li = document.createElement("li")
        li.innerHTML = `<a href="#" class="dropdown-item" data-id="${data.id}" data-value="${data.value}" data-action="click->variant-attribute-select#selectOption">${data.value}</a>`
        this.createItemTarget.closest("li").before(li)

        // Update internal list
        this._allItems.push({
          el: li,
          id: data.id.toString(),
          value: data.value,
          text: data.value.toLowerCase()
        })

        // Select the new value
        this._select(data.id, data.value)

        // Hide create UI
        this.inputWrapperTarget.style.display = "none"
        this.inputTarget.value = ""
        this.createBtnTarget.style.display = "none"
      } else {
        const data = await response.json()
        alert(data.errors ? data.errors.join(", ") : "Error creating value")
      }
    } catch (error) {
      alert("Error creating value")
    } finally {
      btn.disabled = false
    }
  }

  // Private

  _select(id, value) {
    this.comboInputTarget.value = value
    this.hiddenInputTarget.value = id
    this.closeDropdown()
  }

  _filter(query) {
    const q = query.toLowerCase().trim()
    let hasVisible = false

    this._allItems.forEach(item => {
      const match = q === "" || item.text.includes(q)
      item.el.style.display = match ? "" : "none"
      if (match) hasVisible = true
    })

    // Show "create new" option when query doesn't match exactly
    if (this.hasCreateItemTarget) {
      const exactMatch = this._allItems.some(i => i.text === q)
      if (q && !exactMatch) {
        this.createItemTarget.closest("li").style.display = ""
        this.createLabelTarget.textContent = `Criar "${query.trim()}"`
      } else {
        this.createItemTarget.closest("li").style.display = "none"
      }
    }
  }

  _visibleItems() {
    return this._allItems.filter(i => i.el.style.display !== "none")
  }

  _applyHighlight(visible) {
    this._clearHighlight()
    if (this._highlightIndex >= 0 && this._highlightIndex < visible.length) {
      const link = visible[this._highlightIndex].el.querySelector(".dropdown-item")
      link.classList.add("active")
      link.scrollIntoView({ block: "nearest" })
    }
  }

  _clearHighlight() {
    this.dropdownTarget.querySelectorAll(".dropdown-item.active").forEach(el => el.classList.remove("active"))
  }
}
