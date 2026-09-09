import { Controller } from "@hotwired/stimulus"

// Shows only the schedule fields the chosen frequency actually uses:
// daily has no day at all, weekly picks a weekday, monthly a day of the month.
export default class extends Controller {
  static targets = ["kind", "dayWrapper", "weekday", "monthday"]

  connect() {
    this.update()
  }

  update() {
    const kind = this.kindTarget.value

    this.dayWrapperTarget.hidden = kind === "daily"
    this.weekdayTarget.hidden = kind !== "weekly"
    this.monthdayTarget.hidden = kind !== "monthly"

    // A hidden select must not submit a value the model would reject
    // (a weekday 0-6 landing in a monthly automation, or vice versa).
    this.weekdayTarget.querySelector("select").disabled = kind !== "weekly"
    this.monthdayTarget.querySelector("select").disabled = kind !== "monthly"
  }
}
