import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="removable"
export default class extends Controller {
    connect() {
        // Auto-dismiss after 5 seconds
        setTimeout(() => {
            this.remove()
        }, 5000)
    }

    remove() {
        this.element.classList.add("animate__fadeOutRight")
        this.element.addEventListener("animationend", () => {
            this.element.remove()
        })
    }
}
