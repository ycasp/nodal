import { Controller } from "@hotwired/stimulus"

// Hides the flat shipping cost field when the organisation prices shipping at
// dispatch time — in that mode the value is never charged, so leaving it on
// screen only invites the question of why it is being ignored.
export default class extends Controller {
  static targets = ["select", "fixedCost"]

  connect() {
    this.toggle()
  }

  toggle() {
    const deferred = this.selectTarget.value === "calculated_on_dispatch"
    this.fixedCostTarget.classList.toggle("d-none", deferred)
  }
}
