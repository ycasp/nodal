import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    event.preventDefault()

    const modalEl = document.getElementById('emailNotificationModal')
    const form = document.getElementById('emailNotificationForm')
    const countEl = document.getElementById('emailNotificationCount')
    const typeEl = document.getElementById('emailNotificationType')
    const recipientsEl = document.getElementById('emailNotificationRecipients')

    form.action = event.currentTarget.dataset.sendUrl
    countEl.textContent = event.currentTarget.dataset.recipientCount
    typeEl.textContent = event.currentTarget.dataset.discountType

    // Show spinner while loading recipients
    recipientsEl.innerHTML = '<div class="text-center py-2"><div class="spinner-border spinner-border-sm text-muted" role="status"></div></div>'

    const modal = new bootstrap.Modal(modalEl)
    modal.show()

    // Fetch recipient list
    const recipientsUrl = event.currentTarget.dataset.recipientsUrl
    if (recipientsUrl) {
      fetch(recipientsUrl, { headers: { 'Accept': 'text/html' } })
        .then(response => response.text())
        .then(html => { recipientsEl.innerHTML = html })
        .catch(() => { recipientsEl.innerHTML = '' })
    }
  }
}
