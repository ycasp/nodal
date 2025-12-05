import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar-toggle"
// Handles collapsing/expanding the sidebar
export default class extends Controller {
  connect() {
    // Check if sidebar was previously collapsed (stored in localStorage)
    const isCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'
    if (isCollapsed) {
      this.applyCollapsedState(true)
    }
  }

  toggle() {
    const isCollapsed = !this.element.classList.contains('collapsed')
    this.applyCollapsedState(isCollapsed)

    // Store state in localStorage
    localStorage.setItem('sidebarCollapsed', isCollapsed)
  }

  applyCollapsedState(collapsed) {
    const mainContent = document.querySelector('.bo-main-content')
    const navbar = document.querySelector('.bo-navbar')

    if (collapsed) {
      this.element.classList.add('collapsed')
      mainContent?.classList.add('sidebar-collapsed')
      navbar?.classList.add('sidebar-collapsed')
    } else {
      this.element.classList.remove('collapsed')
      mainContent?.classList.remove('sidebar-collapsed')
      navbar?.classList.remove('sidebar-collapsed')
    }
  }
}
