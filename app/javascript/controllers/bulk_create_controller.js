import { Controller } from "@hotwired/stimulus"

// jspreadsheet-ce and jsuites are loaded via <script> tags in the view

// Column indices
const COL = {
  TIPO: 0, SKU: 1, NOME: 2, DESC: 3, PRECO: 4,
  SKU_PAI: 5, CATEGORIA: 6,
  ATTR1_NOME: 7, ATTR1_VAL: 8,
  ATTR2_NOME: 9, ATTR2_VAL: 10,
  ATTR3_NOME: 11, ATTR3_VAL: 12
}
const NUM_COLS = 13
const ATTR_NOME_COLS = [COL.ATTR1_NOME, COL.ATTR2_NOME, COL.ATTR3_NOME]
const ATTR_VAL_COLS = [COL.ATTR1_VAL, COL.ATTR2_VAL, COL.ATTR3_VAL]
const DISABLED_BG = "#f1f5f9"

export default class extends Controller {
  static targets = ["spreadsheet", "submitButton", "errorsPanel", "photoDropZone", "zipInput", "imageInput", "photoFileName", "photoModeSection", "photoMode", "photoWarnings"]
  static values = {
    categories: Array,
    attributes: Array,
    allSkus: Array,
    variableSkus: Array,
    submitUrl: String,
    csrfToken: String,
    attributesUrl: String
  }

  connect() {
    this.errors = []
    this.warnings = []
    this.disabledCells = new Set() // "row,col" keys
    this._updatingType = false
    this._programmaticChange = false
    this._validateTimer = null
    this.waitForLibrary()
  }

  disconnect() {
    if (this.sheet) {
      window.jspreadsheet.destroy(this.spreadsheetTarget)
    }
  }

  waitForLibrary() {
    if (window.jspreadsheet) {
      this.initSpreadsheet()
    } else {
      setTimeout(() => this.waitForLibrary(), 50)
    }
  }

  // ─── Initialization ────────────────────────────────────────

  initSpreadsheet() {
    const categoryNames = this.categoriesValue.map(c => c.name)
    const attributeNames = this.attributesValue.map(a => a.name)

    this.sheet = window.jspreadsheet(this.spreadsheetTarget, {
      data: [[]],
      minDimensions: [NUM_COLS, 10],
      defaultColWidth: 120,
      tableOverflow: true,
      tableWidth: "100%",
      tableHeight: "500px",
      columnDrag: false,
      columns: [
        { title: "Tipo", type: "dropdown", width: 100, source: ["simple", "variable", "variation"] },
        { title: "SKU", type: "text", width: 110 },
        { title: "Nome", type: "text", width: 180 },
        { title: "Descri\u00E7\u00E3o", type: "text", width: 160 },
        { title: "Pre\u00E7o", type: "text", width: 80 },
        { title: "SKU Pai", type: "dropdown", width: 110, source: [...this.variableSkusValue], autocomplete: true },
        { title: "Categoria", type: "dropdown", width: 140, source: categoryNames, autocomplete: true },
        { title: "Attr 1 Nome", type: "dropdown", width: 120, source: attributeNames, autocomplete: true },
        { title: "Attr 1 Valor(es)", type: "dropdown", width: 140, source: [], autocomplete: true },
        { title: "Attr 2 Nome", type: "dropdown", width: 120, source: attributeNames, autocomplete: true },
        { title: "Attr 2 Valor(es)", type: "dropdown", width: 140, source: [], autocomplete: true },
        { title: "Attr 3 Nome", type: "dropdown", width: 120, source: attributeNames, autocomplete: true },
        { title: "Attr 3 Valor(es)", type: "dropdown", width: 140, source: [], autocomplete: true }
      ],
      onchange: this.handleCellChange.bind(this),
      onbeforechange: this.handleBeforeChange.bind(this),
      oneditionstart: this.handleEditionStart.bind(this),
      oninsertrow: this.handleRowChange.bind(this),
      ondeleterow: this.handleRowChange.bind(this),
      contextMenu: (obj, x, y, e) => {
        const row = parseInt(y)
        if (isNaN(row)) return []

        return [
          { title: "Inserir linha acima", onclick: () => { obj.insertRow(1, row, 1) } },
          { title: "Inserir linha abaixo", onclick: () => { obj.insertRow(1, row, 0) } },
          { type: "line" },
          { title: "Remover linha", onclick: () => { obj.deleteRow(row, 1) } }
        ]
      }
    })
  }

  // ─── Event Handlers ────────────────────────────────────────

  handleEditionStart(_instance, _cell, colIndex, rowIndex) {
    const col = parseInt(colIndex)
    const row = parseInt(rowIndex)

    // Only handle attr value columns
    const attrValIndex = ATTR_VAL_COLS.indexOf(col)
    if (attrValIndex === -1) return

    const attrName = this.getCellValue(row, ATTR_NOME_COLS[attrValIndex])
    const config = this.sheet.getConfig()

    if (attrName) {
      // Source = existing values for this attribute in the org
      const attr = this.attributesValue.find(a => a.name === attrName)
      config.columns[col].source = attr ? attr.values.map(v => v.value) : []
    } else {
      config.columns[col].source = []
    }
  }

  handleBeforeChange(_instance, _cell, colIndex, rowIndex, _value) {
    // Allow programmatic changes (auto-fill, type change)
    if (this._updatingType || this._programmaticChange) return

    const key = `${rowIndex},${colIndex}`
    if (this.disabledCells.has(key)) {
      return false // reject manual edit
    }
  }

  handleCellChange(_instance, _cell, colIndex, rowIndex, value) {
    // Skip cascading changes triggered during type update
    if (this._updatingType) return

    const col = parseInt(colIndex)
    const row = parseInt(rowIndex)

    if (col === COL.TIPO) {
      this._updatingType = true
      this.onTipoChange(row, value)
      this._updatingType = false
    }

    if (col === COL.SKU || col === COL.TIPO) {
      this.updateParentSkuDropdown()
    }

    if (col === COL.SKU_PAI) {
      this._programmaticChange = true
      this.autoFillVariation(row)
      this._programmaticChange = false
    }

    // When variation attr values change, auto-update the name
    if (ATTR_VAL_COLS.includes(col)) {
      const tipo = this.getCellValue(row, COL.TIPO)
      if (tipo === "variation") {
        this._programmaticChange = true
        this.autoGenerateVariationName(row)
        this._programmaticChange = false
      }
    }

    // When attr name changes, clear the value and update child variations
    if (ATTR_NOME_COLS.includes(col)) {
      const valCol = ATTR_VAL_COLS[ATTR_NOME_COLS.indexOf(col)]
      this.setCellValue(row, valCol, "")

      const tipo = this.getCellValue(row, COL.TIPO)
      if (tipo === "variable") {
        this._programmaticChange = true
        this.updateChildVariationAttrs(row)
        this._programmaticChange = false
      }
    }

    this.scheduleValidation()
  }

  scheduleValidation() {
    if (this._validateTimer) clearTimeout(this._validateTimer)
    this._validateTimer = setTimeout(() => {
      this._validateTimer = null
      this.validateAll()
      this.renderErrorPanel()
      this.updateSubmitButton()
    }, 150)
  }

  handleRowChange() {
    // Delay to let jspreadsheet finish updating
    setTimeout(() => {
      this.updateParentSkuDropdown()
      this.scheduleValidation()
    }, 50)
  }

  // ─── Type Change Logic ─────────────────────────────────────

  onTipoChange(row, tipo) {
    // Reset all cells: remove from disabled set
    for (let c = 0; c < NUM_COLS; c++) {
      this.disabledCells.delete(`${row},${c}`)
    }

    if (tipo === "simple") {
      // Disable SKU Pai
      this.disabledCells.add(`${row},${COL.SKU_PAI}`)
      this.setCellValue(row, COL.SKU_PAI, "")
    } else if (tipo === "variable") {
      // Disable Preço, SKU Pai, and Attr Values (values are deduced from variations)
      this.disabledCells.add(`${row},${COL.PRECO}`)
      this.setCellValue(row, COL.PRECO, "")
      this.disabledCells.add(`${row},${COL.SKU_PAI}`)
      this.setCellValue(row, COL.SKU_PAI, "")
      ATTR_VAL_COLS.forEach(c => {
        this.disabledCells.add(`${row},${c}`)
        this.setCellValue(row, c, "")
      })
    } else if (tipo === "variation") {
      // Disable Categoria (inherited from parent)
      this.disabledCells.add(`${row},${COL.CATEGORIA}`)
      this.setCellValue(row, COL.CATEGORIA, "")
      // Attr names are auto-filled from parent (readonly)
      ATTR_NOME_COLS.forEach(c => {
        this.disabledCells.add(`${row},${c}`)
      })
      // Try to auto-fill from parent if SKU Pai is set
      this.autoFillVariation(row)
    } else {
      // Empty tipo - clear all readonly
      this.setCellValue(row, COL.SKU_PAI, "")
    }
  }

  // ─── Auto-fill for Variations ──────────────────────────────

  autoFillVariation(row) {
    const tipo = this.getCellValue(row, COL.TIPO)
    if (tipo !== "variation") return

    const skuPai = this.getCellValue(row, COL.SKU_PAI)
    if (!skuPai) return

    const parentRow = this.findVariableRow(skuPai)
    if (!parentRow) return
    const parentData = parentRow.data

    // Auto-fill attr names from parent (readonly)
    for (let i = 0; i < 3; i++) {
      const attrName = parentData[ATTR_NOME_COLS[i]] || ""
      this.setCellValue(row, ATTR_NOME_COLS[i], attrName)
      this.disabledCells.add(`${row},${ATTR_NOME_COLS[i]}`)
    }

    // Auto-inherit category from parent
    const parentCat = parentData[COL.CATEGORIA] || ""
    if (parentCat) {
      this.setCellValue(row, COL.CATEGORIA, parentCat)
    }

    // Auto-generate name
    this.autoGenerateVariationName(row)
  }

  autoGenerateVariationName(row) {
    const tipo = this.getCellValue(row, COL.TIPO)
    if (tipo !== "variation") return

    const skuPai = this.getCellValue(row, COL.SKU_PAI)
    if (!skuPai) return

    const parentRow = this.findVariableRow(skuPai)
    if (!parentRow) return

    const parentName = parentRow.data[COL.NOME] || ""
    const values = ATTR_VAL_COLS
      .map(c => this.getCellValue(row, c))
      .filter(v => v && v.trim() !== "")

    if (parentName && values.length > 0) {
      const name = `${parentName} - ${values.join(" / ")}`
      this.setCellValue(row, COL.NOME, name)
    }
  }

  updateChildVariationAttrs(parentRowIndex) {
    const parentSku = this.getCellValue(parentRowIndex, COL.SKU)
    if (!parentSku) return

    const data = this.sheet.getData()
    data.forEach((rowData, rowIndex) => {
      if (rowData[COL.TIPO] === "variation" && (rowData[COL.SKU_PAI] || "").trim() === parentSku) {
        // Update attr names from parent
        for (let i = 0; i < 3; i++) {
          const attrName = this.getCellValue(parentRowIndex, ATTR_NOME_COLS[i])
          this.setCellValue(rowIndex, ATTR_NOME_COLS[i], attrName)
          // Clear value if attr name changed
          const currentVal = this.getCellValue(rowIndex, ATTR_VAL_COLS[i])
          if (currentVal && attrName !== rowData[ATTR_NOME_COLS[i]]) {
            this.setCellValue(rowIndex, ATTR_VAL_COLS[i], "")
          }
        }
        this.autoGenerateVariationName(rowIndex)
      }
    })
  }

  // ─── Validation ────────────────────────────────────────────

  validateAll() {
    const data = this.sheet.getData()
    this.errors = []
    this.warnings = []

    // Styling is applied at the end via applyAllStyles()

    // Track SKUs for duplicate check
    const productSkuMap = {} // sku -> [rowIndices] for simple/variable
    const variantSkuMap = {} // sku -> [rowIndices] for variation

    data.forEach((rowData, rowIndex) => {
      const tipo = (rowData[COL.TIPO] || "").trim()

      // Skip empty rows
      if (rowData.every(cell => !cell || cell.toString().trim() === "")) return

      // Non-empty row without tipo
      if (!tipo) {
        const hasContent = rowData.some((cell, i) => i > 0 && cell && cell.toString().trim() !== "")
        if (hasContent) {
          this.addError(rowIndex, COL.TIPO, "Selecione o tipo de produto")
        }
        return
      }

      // Nome required for all types
      if (!rowData[COL.NOME] || rowData[COL.NOME].trim() === "") {
        this.addError(rowIndex, COL.NOME, "Nome \u00E9 obrigat\u00F3rio")
      }

      // Description max 250 chars
      if (rowData[COL.DESC] && rowData[COL.DESC].length > 250) {
        this.addError(rowIndex, COL.DESC, "Descri\u00E7\u00E3o n\u00E3o pode exceder 250 caracteres")
      }

      // Warn if description is empty (for simple and variable products)
      if (tipo !== "variation" && (!rowData[COL.DESC] || rowData[COL.DESC].trim() === "")) {
        this.addWarning(rowIndex, COL.DESC, "Conv\u00E9m os produtos terem uma descri\u00E7\u00E3o")
      }

      // Price format validation (if provided)
      if (rowData[COL.PRECO] && rowData[COL.PRECO].trim() !== "") {
        const cleaned = rowData[COL.PRECO].toString().replace(/[^\d.,\-]/g, "")
        if (cleaned === "" || isNaN(cleaned.replace(",", "."))) {
          this.addError(rowIndex, COL.PRECO, "Formato de pre\u00E7o inv\u00E1lido")
        }
      }

      // Track SKU for duplicates (separate maps for products vs variations)
      const sku = (rowData[COL.SKU] || "").trim()
      if (sku) {
        const map = tipo === "variation" ? variantSkuMap : productSkuMap
        if (!map[sku]) map[sku] = []
        map[sku].push(rowIndex)

        // Warning: SKU exists in DB
        if (this.allSkusValue.includes(sku)) {
          this.addWarning(rowIndex, COL.SKU, `SKU '${sku}' j\u00E1 existe \u2014 produto ser\u00E1 atualizado`)
        }
      }

      // === SIMPLE ===
      if (tipo === "simple") {
        // Attr: check for duplicate attr names
        this.validateDuplicateAttrs(rowData, rowIndex)
      }

      // === VARIABLE ===
      if (tipo === "variable") {
        // SKU required
        if (!sku) {
          this.addError(rowIndex, COL.SKU, "SKU \u00E9 obrigat\u00F3rio para produtos vari\u00E1veis")
        }

        // At least 1 attribute name selected
        const hasAttr = ATTR_NOME_COLS.some(nCol => (rowData[nCol] || "").trim() !== "")
        if (!hasAttr) {
          this.addError(rowIndex, COL.ATTR1_NOME, "Selecione pelo menos 1 atributo")
        }

        // Check for duplicate attr names
        this.validateDuplicateAttrs(rowData, rowIndex)

        // Warning: variable without any variation rows
        const hasVariations = data.some(r =>
          r[COL.TIPO] === "variation" && (r[COL.SKU_PAI] || "").trim() === sku
        )
        if (sku && !hasVariations) {
          this.addWarning(rowIndex, COL.TIPO, "Produto vari\u00E1vel sem varia\u00E7\u00F5es definidas")
        }
      }

      // === VARIATION ===
      if (tipo === "variation") {
        const skuPai = (rowData[COL.SKU_PAI] || "").trim()

        // SKU Pai required
        if (!skuPai) {
          this.addError(rowIndex, COL.SKU_PAI, "SKU Pai \u00E9 obrigat\u00F3rio para varia\u00E7\u00F5es")
        } else {
          // SKU Pai must exist as a variable row
          const parent = this.findVariableRow(skuPai)
          if (!parent) {
            this.addError(rowIndex, COL.SKU_PAI, `SKU Pai '${skuPai}' n\u00E3o encontrado`)
          }
        }

        // At least 1 attr value
        const hasVal = ATTR_VAL_COLS.some(c => (rowData[c] || "").trim() !== "")
        if (!hasVal) {
          this.addError(rowIndex, COL.ATTR1_VAL, "Selecione pelo menos 1 valor de atributo")
        }
      }
    })

    // Duplicate SKU check (products and variations checked separately)
    ;[productSkuMap, variantSkuMap].forEach(map => {
      Object.entries(map).forEach(([sku, rows]) => {
        if (rows.length > 1) {
          rows.forEach(r => {
            this.addError(r, COL.SKU, `SKU '${sku}' duplicado (linhas ${rows.map(x => x + 1).join(", ")})`)
          })
        }
      })
    })

    // Apply all styles in one pass
    this.applyAllStyles()
  }

  validateDuplicateAttrs(rowData, rowIndex) {
    const attrNames = ATTR_NOME_COLS
      .map(c => (rowData[c] || "").trim())
      .filter(n => n !== "")

    const seen = new Set()
    attrNames.forEach((name, i) => {
      if (seen.has(name)) {
        this.addError(rowIndex, ATTR_NOME_COLS[i], `Atributo '${name}' duplicado`)
      }
      seen.add(name)
    })
  }

  addError(row, col, message) {
    // Avoid duplicate errors for same cell
    const exists = this.errors.some(e => e.row === row && e.col === col && e.message === message)
    if (!exists) {
      this.errors.push({ row, col, message })
    }
  }

  addWarning(row, col, message) {
    const exists = this.warnings.some(w => w.row === row && w.col === col && w.message === message)
    if (!exists) {
      this.warnings.push({ row, col, message })
    }
  }

  // ─── Styling ────────────────────────────────────────────────

  applyAllStyles() {
    const data = this.sheet.getData()

    // Build lookup sets for O(1) access instead of .some() per cell
    const errorCells = new Set()
    this.errors.forEach(e => errorCells.add(`${e.row},${e.col}`))
    const warningCells = new Set()
    this.warnings.forEach(w => warningCells.add(`${w.row},${w.col}`))

    // Batch all style changes into a single object for setStyle
    const styles = {}
    for (let r = 0; r < data.length; r++) {
      for (let c = 0; c < NUM_COLS; c++) {
        const cellName = window.jspreadsheet.getColumnNameFromId([c, r])
        const key = `${r},${c}`

        if (errorCells.has(key)) {
          styles[cellName] = "background-color: #f8d7da;"
        } else if (warningCells.has(key)) {
          styles[cellName] = "background-color: #fff3cd;"
        } else if (this.disabledCells.has(key)) {
          styles[cellName] = `background-color: ${DISABLED_BG}; color: #94a3b8;`
        } else {
          styles[cellName] = ""
        }
      }
    }
    this.sheet.setStyle(styles)
  }

  // ─── Error Panel ───────────────────────────────────────────

  renderErrorPanel() {
    const panel = this.errorsPanelTarget

    if (this.errors.length === 0 && this.warnings.length === 0) {
      // Check if there are any non-empty rows
      const data = this.sheet.getData()
      const hasData = data.some(row => row.some(cell => cell && cell.toString().trim() !== ""))
      if (!hasData) {
        panel.innerHTML = `
          <div class="card border-secondary">
            <div class="card-body text-center text-muted py-4">
              <i class="fa-solid fa-pencil fa-lg mb-2 d-block"></i>
              <small>Comece a preencher a grelha</small>
            </div>
          </div>`
        return
      }

      panel.innerHTML = `
        <div class="card border-success">
          <div class="card-body text-center py-4">
            <i class="fa-solid fa-check-circle fa-lg text-success mb-2 d-block"></i>
            <small class="text-success fw-semibold">Sem erros \u2014 pronto para criar</small>
          </div>
        </div>`
      return
    }

    let html = '<div class="card border-0">'

    if (this.errors.length > 0) {
      html += `
        <div class="card-header bg-danger text-white py-2 px-3" style="font-size: 13px;">
          <i class="fa-solid fa-exclamation-triangle me-1"></i>
          Erros (${this.errors.length})
        </div>
        <div class="card-body p-2" style="max-height: 200px; overflow-y: auto;">`

      this.errors.forEach(e => {
        html += `
          <div class="error-item text-danger" data-action="click->bulk-create#focusCell"
               data-row="${e.row}" data-col="${e.col}">
            <strong>Linha ${e.row + 1}:</strong> ${e.message}
          </div>`
      })
      html += '</div>'
    }

    if (this.warnings.length > 0) {
      html += `
        <div class="card-header bg-warning py-2 px-3" style="font-size: 13px;">
          <i class="fa-solid fa-info-circle me-1"></i>
          Avisos (${this.warnings.length})
        </div>
        <div class="card-body p-2" style="max-height: 150px; overflow-y: auto;">`

      this.warnings.forEach(w => {
        html += `
          <div class="error-item text-warning-emphasis" data-action="click->bulk-create#focusCell"
               data-row="${w.row}" data-col="${w.col}">
            <strong>Linha ${w.row + 1}:</strong> ${w.message}
          </div>`
      })
      html += '</div>'
    }

    html += '</div>'
    panel.innerHTML = html
  }

  focusCell(event) {
    const row = parseInt(event.currentTarget.dataset.row)
    const col = parseInt(event.currentTarget.dataset.col)
    const cellName = window.jspreadsheet.getColumnNameFromId([col, row])
    this.sheet.updateSelectionFromCoords(col, row, col, row)
  }

  updateSubmitButton() {
    const data = this.sheet.getData()
    const hasData = data.some(row => (row[COL.TIPO] || "").trim() !== "")
    this.submitButtonTarget.disabled = this.errors.length > 0 || !hasData
  }

  // ─── Cell Helpers ──────────────────────────────────────────

  getCellValue(row, col) {
    const cellName = window.jspreadsheet.getColumnNameFromId([col, row])
    return (this.sheet.getValue(cellName) || "").toString().trim()
  }

  setCellValue(row, col, value) {
    const cellName = window.jspreadsheet.getColumnNameFromId([col, row])
    const current = this.sheet.getValue(cellName)
    if (current !== value) {
      this.sheet.setValue(cellName, value, true)
    }
  }

  setCellStyle(row, col, bgColor) {
    const cellName = window.jspreadsheet.getColumnNameFromId([col, row])
    this.sheet.setStyle(cellName, "background-color", bgColor)
  }

  setCellDisabled(row, col, disabled) {
    const key = `${row},${col}`
    if (disabled) {
      this.disabledCells.add(key)
    } else {
      this.disabledCells.delete(key)
    }
    // Visual styling is handled by applyAllStyles()
  }

  findVariableRow(sku) {
    if (!sku) return null

    const data = this.sheet.getData()
    for (let i = 0; i < data.length; i++) {
      if (data[i][COL.TIPO] === "variable" && (data[i][COL.SKU] || "").trim() === sku) {
        return { index: i, data: data[i] }
      }
    }

    // Check DB variable SKUs
    if (this.variableSkusValue.includes(sku)) {
      return { index: -1, data: [] } // exists in DB but not in grid
    }
    return null
  }

  updateParentSkuDropdown() {
    const data = this.sheet.getData()
    const gridSkus = []

    data.forEach(row => {
      if (row[COL.TIPO] === "variable" && row[COL.SKU] && row[COL.SKU].trim() !== "") {
        gridSkus.push(row[COL.SKU].trim())
      }
    })

    const allSkus = [...new Set([...this.variableSkusValue, ...gridSkus])]
    const options = this.sheet.getConfig()
    options.columns[COL.SKU_PAI].source = allSkus
  }

  // ─── Row Actions ───────────────────────────────────────────

  addRow() {
    this.sheet.insertRow()
  }

  removeRow() {
    const selected = this.sheet.getSelectedRows()
    if (selected && selected.length > 0) {
      const rows = [...selected].sort((a, b) => b - a)
      rows.forEach(row => this.sheet.deleteRow(row))
    } else {
      const data = this.sheet.getData()
      if (data.length > 1) {
        this.sheet.deleteRow(data.length - 1)
      }
    }
  }

  // ─── Photo Upload ──────────────────────────────────────────

  photoDragover(event) {
    event.preventDefault()
  }

  photoDragenter(event) {
    event.preventDefault()
    this.photoDropZoneTarget.classList.add("border-primary", "bg-light")
  }

  photoDragleave(event) {
    event.preventDefault()
    this.photoDropZoneTarget.classList.remove("border-primary", "bg-light")
  }

  photoDrop(event) {
    event.preventDefault()
    this.photoDropZoneTarget.classList.remove("border-primary", "bg-light")

    const files = event.dataTransfer.files
    if (files.length === 0) return

    const file = files[0]
    if (file.name.toLowerCase().endsWith(".zip")) {
      this.zipInputTarget.files = files
      this.showPhotoInfo(`<i class="fa-solid fa-file-zipper text-warning me-1"></i> ${file.name}`)
    } else {
      this.imageInputTarget.files = files
      this.showPhotoInfo(`<i class="fa-solid fa-images text-success me-1"></i> ${files.length} imagem(ns)`)
      this.checkPhotoMatches(files)
    }
  }

  zipSelected() {
    if (this.zipInputTarget.files.length > 0) {
      this.showPhotoInfo(`<i class="fa-solid fa-file-zipper text-warning me-1"></i> ${this.zipInputTarget.files[0].name}`)
    }
  }

  imagesSelected() {
    if (this.imageInputTarget.files.length > 0) {
      this.showPhotoInfo(`<i class="fa-solid fa-images text-success me-1"></i> ${this.imageInputTarget.files.length} imagem(ns)`)
      this.checkPhotoMatches(this.imageInputTarget.files)
    }
  }

  showPhotoInfo(html) {
    this.photoFileNameTarget.innerHTML = html
    this.photoModeSectionTarget.classList.remove("d-none")
  }

  extractSkuFromFilename(filename) {
    const name = filename.replace(/\.[^.]+$/, "")
    const skuPart = name.split(/\s+/)[0]
    return skuPart ? skuPart.toLowerCase() : null
  }

  checkPhotoMatches(files) {
    if (!this.hasPhotoWarningsTarget) return
    if (!this.excludedPhotos) this.excludedPhotos = new Set()

    const data = this.sheet.getData()
    const gridSkus = new Set()
    data.forEach(row => {
      const sku = (row[COL.SKU] || "").trim().toLowerCase()
      if (sku) gridSkus.add(sku)
    })
    // Also include existing SKUs from DB
    this.allSkusValue.forEach(s => gridSkus.add(s.toLowerCase()))

    const unmatched = []
    for (const file of files) {
      if (this.excludedPhotos.has(file.name)) continue
      const sku = this.extractSkuFromFilename(file.name)
      if (!sku) { unmatched.push(file.name); continue }
      // Strip trailing -N suffix for multi-photo matching
      const baseSku = sku.replace(/-\d+$/, "")
      if (!gridSkus.has(sku) && !gridSkus.has(baseSku)) {
        unmatched.push(file.name)
      }
    }

    if (unmatched.length > 0) {
      this.photoWarningsTarget.innerHTML = `
        <div class="alert alert-warning py-2 px-3 mt-2 mb-0" style="font-size: 13px;">
          <i class="fa-solid fa-triangle-exclamation me-1"></i>
          <strong>${unmatched.length} foto(s)</strong> sem SKU correspondente na grelha:
          <div class="mt-1">${unmatched.map(f =>
            `<span class="d-inline-flex align-items-center me-2 mb-1"><code>${f}</code>
             <button type="button" class="btn btn-sm p-0 ms-1 text-danger" data-action="click->bulk-create#removePhoto" data-photo-name="${f}" title="Remover">
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
    if (!this.excludedPhotos) this.excludedPhotos = new Set()
    this.excludedPhotos.add(name)

    // Rebuild the filtered file list
    this.rebuildImageInput()
    this.checkPhotoMatches(this.imageInputTarget.files)
    this.updatePhotoCount()
  }

  rebuildImageInput() {
    const dt = new DataTransfer()
    for (const file of this.imageInputTarget.files) {
      if (!this.excludedPhotos.has(file.name)) dt.items.add(file)
    }
    this.imageInputTarget.files = dt.files
  }

  updatePhotoCount() {
    const count = this.imageInputTarget.files.length
    if (count > 0) {
      this.showPhotoInfo(`<i class="fa-solid fa-images text-success me-1"></i> ${count} imagem(ns)`)
    } else {
      this.photoFileNameTarget.innerHTML = `<span class="text-muted">${this.photoFileNameTarget.dataset.hint || ""}</span>`
      this.photoModeSectionTarget.classList.add("d-none")
      this.photoWarningsTarget.innerHTML = ""
    }
  }

  // ─── Submit ────────────────────────────────────────────────

  submit() {
    this.validateAll()
    if (this.errors.length > 0) {
      this.renderErrorPanel()
      return
    }

    const data = this.sheet.getData()
    const rows = []

    data.forEach(row => {
      const tipo = (row[COL.TIPO] || "").trim()
      if (!tipo) return

      rows.push({
        tipo,
        sku: (row[COL.SKU] || "").trim(),
        nome: (row[COL.NOME] || "").trim(),
        descricao: (row[COL.DESC] || "").trim(),
        preco: (row[COL.PRECO] || "").trim(),
        sku_pai: (row[COL.SKU_PAI] || "").trim(),
        categoria: (row[COL.CATEGORIA] || "").trim(),
        atributo_1_nome: (row[COL.ATTR1_NOME] || "").trim(),
        atributo_1_valores: (row[COL.ATTR1_VAL] || "").trim(),
        atributo_2_nome: (row[COL.ATTR2_NOME] || "").trim(),
        atributo_2_valores: (row[COL.ATTR2_VAL] || "").trim(),
        atributo_3_nome: (row[COL.ATTR3_NOME] || "").trim(),
        atributo_3_valores: (row[COL.ATTR3_VAL] || "").trim()
      })
    })

    if (rows.length === 0) return

    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> A processar...'

    this.element.dispatchEvent(new CustomEvent("form-guard:dismiss", { bubbles: true }))

    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.submitUrlValue
    form.enctype = "multipart/form-data"
    form.style.display = "none"
    form.setAttribute("data-turbo", "false")

    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = this.csrfTokenValue
    form.appendChild(csrfInput)

    rows.forEach((row, i) => {
      Object.entries(row).forEach(([key, value]) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = `rows[${i}][${key}]`
        input.value = value
        form.appendChild(input)
      })
    })

    // Move original file inputs into the form (cloneNode doesn't transfer files)
    if (this.hasZipInputTarget && this.zipInputTarget.files.length > 0) {
      form.appendChild(this.zipInputTarget)
    }
    if (this.hasImageInputTarget && this.imageInputTarget.files.length > 0) {
      form.appendChild(this.imageInputTarget)
    }

    // Include photo mode
    const photoMode = document.querySelector('input[name="photo_mode"]:checked')
    if (photoMode) {
      const modeInput = document.createElement("input")
      modeInput.type = "hidden"
      modeInput.name = "photo_mode"
      modeInput.value = photoMode.value
      form.appendChild(modeInput)
    }

    document.body.appendChild(form)
    form.submit()
  }
}
