import { Controller } from "@hotwired/stimulus"

// Adds/removes rows in a table where each row is a repeated nested-form record.
// Expects a <template data-repeatable-rows-target="template"> with placeholder
// "__INDEX__" inside input names to be rewritten to a unique index per inserted row.
export default class extends Controller {
  static targets = ["body", "template", "row"]

  connect() {
    this.nextIndex = this.rowTargets.length
  }

  addRow(event) {
    event.preventDefault()
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", this.nextIndex)
    this.bodyTarget.insertAdjacentHTML("beforeend", html)
    this.nextIndex += 1
  }

  removeRow(event) {
    event.preventDefault()
    event.currentTarget.closest("tr").remove()
  }
}
