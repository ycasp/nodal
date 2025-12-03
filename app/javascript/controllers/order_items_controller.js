import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "total"]

  connect() {
    console.log("Order items controller connected!")
    this.index = this.containerTarget.querySelectorAll("tr").length
    this.updateTotal()
  }

  add(event) {
    event.preventDefault()
    console.log("Add button clicked!")
    const content = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, new Date().getTime())
    console.log("Template content:", content)
    this.containerTarget.insertAdjacentHTML("beforeend", content)
    this.index++
    this.updateTotal()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("tr")

    // If there's a hidden _destroy field, mark it for destruction
    const destroyInput = row.querySelector("input[name*='_destroy']")
    if (destroyInput) {
      destroyInput.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }

    this.updateTotal()
  }

  updatePrice(event) {
    const row = event.target.closest("tr")
    const select = event.target
    const selectedOption = select.options[select.selectedIndex]
    const price = selectedOption.dataset.price || 0

    const unitPriceInput = row.querySelector("[data-price-field]")
    if (unitPriceInput) {
      unitPriceInput.value = parseFloat(price).toFixed(2)
    }

    this.calculateLineTotal(row)
    this.updateTotal()
  }

  calculate(event) {
    const row = event.target.closest("tr")
    this.calculateLineTotal(row)
    this.updateTotal()
  }

  calculateLineTotal(row) {
    const quantity = parseFloat(row.querySelector("[data-quantity-field]")?.value) || 0
    const unitPrice = parseFloat(row.querySelector("[data-price-field]")?.value) || 0
    const lineTotal = quantity * unitPrice

    const lineTotalEl = row.querySelector("[data-line-total]")
    if (lineTotalEl) {
      lineTotalEl.textContent = lineTotal.toFixed(2)
    }
  }

  updateTotal() {
    const lineTotals = this.containerTarget.querySelectorAll("[data-line-total]")
    let total = 0

    lineTotals.forEach(el => {
      const row = el.closest("tr")
      if (row && row.style.display !== "none") {
        total += parseFloat(el.textContent) || 0
      }
    })

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = total.toFixed(2)
    }
  }
}
