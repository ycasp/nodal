import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-upload"
export default class extends Controller {
  static targets = ["input", "dropZone", "fileName"]

  connect() {
    this.dragCounter = 0
  }

  dragover(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  dragenter(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dragCounter++
    this.dropZoneTarget.classList.add("border-primary", "bg-light")
  }

  dragleave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dragCounter--
    if (this.dragCounter === 0) {
      this.dropZoneTarget.classList.remove("border-primary", "bg-light")
    }
  }

  drop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dragCounter = 0
    this.dropZoneTarget.classList.remove("border-primary", "bg-light")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      const file = files[0]
      if (this.isValidFile(file)) {
        this.inputTarget.files = files
        this.updateFileName(file.name)
      }
    }
  }

  fileSelected(event) {
    const file = event.target.files[0]
    if (file) {
      this.updateFileName(file.name)
    }
  }

  isValidFile(file) {
    const validExtensions = [".csv"]
    const fileName = file.name.toLowerCase()
    return validExtensions.some(ext => fileName.endsWith(ext))
  }

  updateFileName(name) {
    if (this.hasFileNameTarget) {
      this.fileNameTarget.innerHTML = `<i class="fa-solid fa-file-csv text-success me-2"></i><strong>${name}</strong>`
    }
  }
}
