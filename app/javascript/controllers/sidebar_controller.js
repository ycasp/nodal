import { Controller } from "@hotwired/stimulus"

// Sidebar toggle controller
// Handles collapse/expand functionality with localStorage persistence
export default class extends Controller {
  static targets = []

  connect() {
    // Restore collapsed state from localStorage
    const isCollapsed = localStorage.getItem("sidebarCollapsed") === "true"
    if (isCollapsed) {
      this.element.classList.add("collapsed")
    }
  }

  toggle() {
    this.element.classList.toggle("collapsed")

    // Persist state to localStorage
    const isCollapsed = this.element.classList.contains("collapsed")
    localStorage.setItem("sidebarCollapsed", isCollapsed)

    // Dispatch custom event for other components to react
    this.dispatch("toggled", { detail: { collapsed: isCollapsed } })
  }

  // For mobile: open sidebar
  open() {
    this.element.classList.add("mobile-open")
    document.body.classList.add("sidebar-open")
  }

  // For mobile: close sidebar
  close() {
    this.element.classList.remove("mobile-open")
    document.body.classList.remove("sidebar-open")
  }

  // Toggle mobile sidebar
  toggleMobile() {
    this.element.classList.toggle("mobile-open")
    document.body.classList.toggle("sidebar-open")
  }
}
