import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "attributesSection", "attributeCard", "valuesSection"]

  toggleAttributes() {
    const isEnabled = this.toggleTarget.checked

    if (this.hasAttributesSectionTarget) {
      this.attributesSectionTarget.style.display = isEnabled ? "block" : "none"
    }
  }

  toggleAttribute(event) {
    const checkbox = event.target
    const card = checkbox.closest("[data-variant-configuration-target='attributeCard']")
    const valuesSection = card.querySelector("[data-variant-configuration-target='valuesSection']")

    if (valuesSection) {
      if (checkbox.checked) {
        valuesSection.classList.remove("d-none")
      } else {
        valuesSection.classList.add("d-none")
        // Uncheck all value checkboxes when attribute is unchecked
        valuesSection.querySelectorAll("input[type='checkbox']").forEach(cb => {
          cb.checked = false
        })
      }
    }
  }

  filterValues(event) {
    const query = event.target.value.toLowerCase().trim().replace(/,/g, ".")
    const card = event.target.closest("[data-variant-configuration-target='attributeCard']")
    const checkboxes = card.querySelectorAll(".form-check")
    let hasMatch = false

    checkboxes.forEach(item => {
      const label = item.querySelector(".form-check-label")
      if (!label) return
      const text = label.textContent.toLowerCase().trim()
      const visible = !query || text.includes(query)
      item.style.display = visible ? "" : "none"
      if (visible && query) hasMatch = true
    })

    // Show or hide the "create new value" button
    const createBtn = card.querySelector(".create-value-btn")
    if (createBtn) {
      if (query && !hasMatch) {
        createBtn.style.display = ""
        createBtn.dataset.newValue = event.target.value.trim().replace(/,/g, ".")
        createBtn.querySelector(".create-value-name").textContent = event.target.value.trim().replace(/,/g, ".")
      } else {
        createBtn.style.display = "none"
      }
    }
  }

  async createValue(event) {
    const btn = event.currentTarget
    const card = btn.closest("[data-variant-configuration-target='attributeCard']")
    const attributeId = card.dataset.attributeId
    const newValue = btn.dataset.newValue
    const orgSlug = window.location.pathname.split("/")[1]

    btn.disabled = true

    try {
      const csrfToken = document.querySelector("meta[name='csrf-token']").content
      const response = await fetch(`/${orgSlug}/bo/product_attributes/${attributeId}/product_attribute_values`, {
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

        // Add the new checkbox to the values list
        const valuesContainer = card.querySelector(".d-flex.flex-wrap.gap-2")
        const formCheck = document.createElement("div")
        formCheck.classList.add("form-check")
        formCheck.innerHTML = `
          <input type="checkbox"
                 name="product[available_attribute_value_ids][]"
                 value="${data.id}"
                 class="form-check-input"
                 id="value_${data.id}"
                 checked>
          <label class="form-check-label" for="value_${data.id}">
            <span class="badge bg-secondary">${data.value}</span>
          </label>
        `
        valuesContainer.appendChild(formCheck)

        // Clear the search input and hide the create button
        const searchInput = card.querySelector("input[type='text'][data-action*='filterValues']")
        if (searchInput) searchInput.value = ""
        btn.style.display = "none"

        // Show all checkboxes again
        card.querySelectorAll(".form-check").forEach(item => {
          item.style.display = ""
        })
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
}
