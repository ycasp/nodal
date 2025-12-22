import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar-toggle"
// Handles collapsing/expanding the sidebar
export default class extends Controller {
  connect() {
    // Restore collapsed state from localStorage
    const isCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'
    if (isCollapsed) {
      this.element.classList.add('collapsed')
    }
  }

  toggle() {
    this.element.classList.toggle('collapsed')

    // Persist state to localStorage
    const isCollapsed = this.element.classList.contains('collapsed')
    localStorage.setItem('sidebarCollapsed', isCollapsed)
  }
}
