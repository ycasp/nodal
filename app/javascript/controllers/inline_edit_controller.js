import { Controller } from "@hotwired/stimulus"

// Auto-saves a single editable field via PATCH to a JSON endpoint when the
// input loses focus. Used by the "manage logins" modal so reps can update
// contact_name / contact_phone without explicit save buttons.
//
// Per field, expects:
//   - data-inline-edit-target="field"
//   - data-field="<attr-name-on-server>"
//   - data-action="blur->inline-edit#save"
//
// Per wrapper, expects:
//   - data-inline-edit-url-value="<PATCH endpoint>"
//   - data-inline-edit-saved-text-value, data-inline-edit-error-text-value
//
// The wrapper-level "status" target receives transient feedback text.
export default class extends Controller {
  static targets = ["field", "status"]
  static values = {
    url: String,
    savedText: { type: String, default: "Saved" },
    errorText: { type: String, default: "Save failed" }
  }

  connect() {
    this.originals = new WeakMap()
    this.fieldTargets.forEach((el) => this.originals.set(el, el.value))
  }

  async save(event) {
    const input = event.currentTarget
    const fieldName = input.dataset.field
    if (!fieldName) return
    const newValue = input.value
    if (newValue === this.originals.get(input)) return

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    const body = new FormData()
    body.append(`customer_user[${fieldName}]`, newValue)

    input.classList.remove("is-invalid", "is-valid")
    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        body,
        headers: {
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": csrf || ""
        },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      this.originals.set(input, newValue)
      input.classList.add("is-valid")
      this.flashStatus(this.savedTextValue, "text-success")
    } catch (err) {
      input.classList.add("is-invalid")
      this.flashStatus(this.errorTextValue, "text-danger")
    }
  }

  flashStatus(text, klass) {
    if (!this.hasStatusTarget) return
    const el = this.statusTarget
    el.classList.remove("text-success", "text-danger")
    el.classList.add(klass)
    el.textContent = text
    clearTimeout(this._statusTimer)
    this._statusTimer = setTimeout(() => { el.textContent = "" }, 2000)
  }
}
