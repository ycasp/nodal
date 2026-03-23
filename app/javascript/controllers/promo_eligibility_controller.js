import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customerPicker", "radio"]

  toggle() {
    const selected = this.element.querySelector('input[name="promo_code[eligibility]"]:checked')
    if (selected && selected.value === 'specific_customers') {
      this.customerPickerTarget.classList.remove('d-none')
    } else {
      this.customerPickerTarget.classList.add('d-none')
    }
  }
}
