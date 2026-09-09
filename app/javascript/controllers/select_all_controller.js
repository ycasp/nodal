import { Controller } from "@hotwired/stimulus"

// Bulk-toggle a group of checkboxes within this element. The group is matched
// by class via the `checkbox-class` value (defaults to "bulk-select").
//
// Usage:
//   <form data-controller="select-all"
//         data-select-all-checkbox-class="my-row-checkbox">
//     <input type="checkbox" data-action="select-all#toggle">
//     <input type="checkbox" class="my-row-checkbox" name="ids[]" value="1">
//     ...
//   </form>
export default class extends Controller {
  static values = { checkboxClass: { type: String, default: "bulk-select" } }

  toggle(event) {
    const checked = event.target.checked
    this.element
      .querySelectorAll(`input.${this.checkboxClassValue}[type="checkbox"]`)
      .forEach(cb => { cb.checked = checked })
  }
}
