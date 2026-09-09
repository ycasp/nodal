import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressBar", "percentText", "statusText", "progressSection", "resultSection", "cancelSection", "icon", "title", "subtitle"]
  static values = { url: String, redirect: String }

  connect() {
    this.poll()
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue)
      const data = await response.json()

      this.updateProgress(data)

      if (data.status === "completed") {
        this.hideCancelButton()
        this.showResult(data)
      } else if (data.status === "failed") {
        this.hideCancelButton()
        this.showError(data)
      } else if (data.status === "cancelled") {
        this.hideCancelButton()
        this.showCancelled()
      } else {
        this.timer = setTimeout(() => this.poll(), 2000)
      }
    } catch {
      this.timer = setTimeout(() => this.poll(), 3000)
    }
  }

  updateProgress(data) {
    const pct = data.progress_percentage || 0
    this.progressBarTarget.style.width = `${pct}%`
    this.percentTextTarget.textContent = `${pct}%`

    if (data.status === "running") {
      const progress = data.progress || 0
      const total = data.total || "?"
      this.statusTextTarget.textContent = `A processar... ${progress}/${total}`
    }
  }

  showResult(data) {
    this.progressBarTarget.style.width = "100%"
    this.progressBarTarget.classList.remove("progress-bar-animated")
    this.progressBarTarget.classList.add("bg-success")
    this.percentTextTarget.textContent = "100%"
    this.statusTextTarget.textContent = "Concluído"

    if (this.hasIconTarget) {
      this.iconTarget.className = "fa-solid fa-check fa-lg"
    }
    if (this.hasSubtitleTarget) {
      this.subtitleTarget.textContent = "Processo terminado com sucesso"
    }

    const result = data.result || {}
    this.resultSectionTarget.classList.remove("d-none")
    this.resultSectionTarget.innerHTML = this.buildResultHtml(result, data.download_url)
  }

  hideCancelButton() {
    if (this.hasCancelSectionTarget) {
      this.cancelSectionTarget.classList.add("d-none")
    }
  }

  showCancelled() {
    this.progressBarTarget.classList.remove("progress-bar-animated")
    this.progressBarTarget.classList.add("bg-secondary")
    this.statusTextTarget.textContent = "Cancelado"

    if (this.hasIconTarget) {
      this.iconTarget.className = "fa-solid fa-ban fa-lg"
    }
    if (this.hasSubtitleTarget) {
      this.subtitleTarget.textContent = "Processo cancelado"
    }

    this.resultSectionTarget.classList.remove("d-none")
    this.resultSectionTarget.innerHTML = `
      <div class="alert alert-secondary mt-3 mb-0">
        <i class="fa-solid fa-ban me-1"></i> Este processo foi cancelado.
      </div>
      <a href="${this.redirectValue}" class="btn btn-primary mt-2"><i class="fa-solid fa-arrow-left me-1"></i> Voltar</a>`
  }

  showError(data) {
    this.progressBarTarget.classList.remove("progress-bar-animated")
    this.progressBarTarget.classList.add("bg-danger")
    this.statusTextTarget.textContent = "Erro"

    if (this.hasIconTarget) {
      this.iconTarget.className = "fa-solid fa-xmark fa-lg"
    }
    if (this.hasSubtitleTarget) {
      this.subtitleTarget.textContent = "Ocorreu um erro"
    }

    this.resultSectionTarget.classList.remove("d-none")
    this.resultSectionTarget.innerHTML = `
      <div class="alert alert-danger mt-3 mb-0">
        <i class="fa-solid fa-triangle-exclamation me-1"></i>
        ${data.error_message || "Erro desconhecido"}
      </div>`
  }

  buildResultHtml(result, downloadUrl) {
    const stats = result.stats || {}
    const errors = result.errors || []

    let html = '<div class="mt-3">'

    // Stats
    const statItems = []
    if (stats.products_created || stats.created) statItems.push(`<strong>${stats.products_created || stats.created}</strong> produto(s) criado(s)`)
    if (stats.products_updated || stats.updated) statItems.push(`<strong>${stats.products_updated || stats.updated}</strong> produto(s) atualizado(s)`)
    if (stats.variants_created) statItems.push(`<strong>${stats.variants_created}</strong> variante(s) criada(s)`)
    if (stats.attributes_created) statItems.push(`<strong>${stats.attributes_created}</strong> atributo(s) criado(s)`)
    if (stats.photos_attached) statItems.push(`<strong>${stats.photos_attached}</strong> foto(s) anexada(s)`)
    if (stats.products_matched) statItems.push(`<strong>${stats.products_matched}</strong> produto(s) com foto`)
    if (stats.product_count) statItems.push(`<strong>${stats.product_count}</strong> produto(s) no catálogo`)
    if (stats.record_count) statItems.push(`<strong>${stats.record_count}</strong> registo(s) exportado(s)`)

    if (statItems.length > 0) {
      html += `<div class="alert alert-success"><i class="fa-solid fa-check-circle me-1"></i> ${statItems.join(" &middot; ")}</div>`
    }

    // Errors
    if (errors.length > 0) {
      html += `<div class="alert alert-warning"><i class="fa-solid fa-triangle-exclamation me-1"></i> <strong>${errors.length} erro(s):</strong><ul class="mb-0 mt-1">`
      errors.forEach(e => {
        const field = e.field ? ` (${e.field})` : ""
        const row = e.row ? `Linha ${e.row}` : ""
        html += `<li>${row}${field}: ${e.message}</li>`
      })
      html += "</ul></div>"
    }

    // Download link (if file attached)
    if (downloadUrl) {
      html += `<a href="${downloadUrl}" class="btn btn-success mt-2 me-2"><i class="fa-solid fa-download me-1"></i> Descarregar</a>`
    }

    // Back link
    html += `<a href="${this.redirectValue}" class="btn btn-primary mt-2"><i class="fa-solid fa-arrow-left me-1"></i> Voltar</a>`
    html += "</div>"
    return html
  }
}
