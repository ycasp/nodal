import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zipInput", "imageInput", "zipDropZone", "zipFileName", "photoModeSection", "photoWarnings"]
  static values = { allSkus: Array }

  connect() {
    this.dragCounter = 0
    this.excludedPhotos = new Set()
  }

  zipDragover(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  zipDragenter(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dragCounter++
    this.zipDropZoneTarget.classList.add("border-primary", "bg-light")
  }

  zipDragleave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dragCounter--
    if (this.dragCounter === 0) {
      this.zipDropZoneTarget.classList.remove("border-primary", "bg-light")
    }
  }

  zipDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dragCounter = 0
    this.zipDropZoneTarget.classList.remove("border-primary", "bg-light")

    const files = event.dataTransfer.files
    if (files.length === 0) return

    const file = files[0]
    if (file.name.toLowerCase().endsWith(".zip")) {
      this.zipInputTarget.files = files
      this.updateFileName(`<i class="fa-solid fa-file-zipper text-warning me-2"></i><strong>${file.name}</strong>`)
      this.photoModeSectionTarget.classList.remove("d-none")
    } else if (this.areImageFiles(files)) {
      this.imageInputTarget.files = files
      this.updateFileName(`<i class="fa-solid fa-images text-success me-2"></i><strong>${files.length} imagem(ns)</strong>`)
      this.photoModeSectionTarget.classList.remove("d-none")
      this.checkPhotoMatches()
    }
  }

  zipSelected() {
    if (this.zipInputTarget.files.length > 0) {
      this.updateFileName(`<i class="fa-solid fa-file-zipper text-warning me-2"></i><strong>${this.zipInputTarget.files[0].name}</strong>`)
      this.photoModeSectionTarget.classList.remove("d-none")
    } else {
      this.checkIfPhotosSelected()
    }
  }

  imagesSelected() {
    if (this.imageInputTarget.files.length > 0) {
      this.updateFileName(`<i class="fa-solid fa-images text-success me-2"></i><strong>${this.imageInputTarget.files.length} imagem(ns)</strong>`)
      this.photoModeSectionTarget.classList.remove("d-none")
      this.checkPhotoMatches()
    } else {
      this.checkIfPhotosSelected()
    }
  }

  checkIfPhotosSelected() {
    const hasZip = this.zipInputTarget.files.length > 0
    const hasImages = this.imageInputTarget.files.length > 0
    if (!hasZip && !hasImages) {
      this.photoModeSectionTarget.classList.add("d-none")
    }
  }

  areImageFiles(files) {
    const imageExts = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
    return Array.from(files).every(f => imageExts.some(ext => f.name.toLowerCase().endsWith(ext)))
  }

  updateFileName(html) {
    if (this.hasZipFileNameTarget) {
      this.zipFileNameTarget.innerHTML = html
    }
  }

  extractSkuFromFilename(filename) {
    const name = filename.replace(/\.[^.]+$/, "")
    const skuPart = name.split(/\s+/)[0]
    return skuPart ? skuPart.toLowerCase() : null
  }

  checkPhotoMatches() {
    if (!this.hasPhotoWarningsTarget || !this.hasAllSkusValue) return

    const files = this.imageInputTarget.files
    if (!files || files.length === 0) {
      this.photoWarningsTarget.innerHTML = ""
      return
    }

    const knownSkus = new Set(this.allSkusValue.map(s => s.toLowerCase()))

    const unmatched = []
    for (const file of files) {
      if (this.excludedPhotos.has(file.name)) continue
      const sku = this.extractSkuFromFilename(file.name)
      if (!sku) { unmatched.push(file.name); continue }
      const baseSku = sku.replace(/-\d+$/, "")
      if (!knownSkus.has(sku) && !knownSkus.has(baseSku)) {
        unmatched.push(file.name)
      }
    }

    if (unmatched.length > 0) {
      this.photoWarningsTarget.innerHTML = `
        <div class="alert alert-warning py-2 px-3 mt-2 mb-0" style="font-size: 13px;">
          <i class="fa-solid fa-triangle-exclamation me-1"></i>
          <strong>${unmatched.length} foto(s)</strong> sem SKU correspondente:
          <div class="mt-1">${unmatched.map(f =>
            `<span class="d-inline-flex align-items-center me-2 mb-1"><code>${f}</code>
             <button type="button" class="btn btn-sm p-0 ms-1 text-danger" data-action="click->import-form#removePhoto" data-photo-name="${f}" title="Remover">
               <i class="fa-solid fa-xmark"></i>
             </button></span>`
          ).join("")}</div>
        </div>`
    } else {
      this.photoWarningsTarget.innerHTML = ""
    }
  }

  removePhoto(event) {
    const name = event.currentTarget.dataset.photoName
    this.excludedPhotos.add(name)

    const dt = new DataTransfer()
    for (const file of this.imageInputTarget.files) {
      if (!this.excludedPhotos.has(file.name)) dt.items.add(file)
    }
    this.imageInputTarget.files = dt.files

    if (this.imageInputTarget.files.length > 0) {
      this.updateFileName(`<i class="fa-solid fa-images text-success me-2"></i><strong>${this.imageInputTarget.files.length} imagem(ns)</strong>`)
    } else {
      this.updateFileName("")
      this.checkIfPhotosSelected()
    }
    this.checkPhotoMatches()
  }
}
