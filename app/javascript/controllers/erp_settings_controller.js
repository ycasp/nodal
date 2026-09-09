import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "enabledToggle",
    "settingsPanel",
    "adapterSelect",
    "credentialsCard",
    "credentialsFields",
    "testButton",
    "testResult",
    "fieldMappingCard",
    "fetchSampleButton",
    "fetchSampleResult",
    "productsMappingSection",
    "productsMappingBody",
    "customersMappingSection",
    "customersMappingBody",
    "productMapping",
    "customerMapping"
  ]

  // Nodal field definitions
  static productFields = [
    { key: 'external_id', label: 'External ID', required: true, description: "ERP's unique identifier" },
    { key: 'name', label: 'Name', required: true, description: 'Product name' },
    { key: 'sku', label: 'SKU', required: false, description: 'Stock keeping unit' },
    { key: 'description', label: 'Description', required: false, description: 'Product description' },
    { key: 'unit_price', label: 'Unit Price', required: false, description: 'Price (will be converted to cents)' },
    { key: 'available', label: 'Available', required: false, description: 'Availability status (boolean)' }
  ]

  static customerFields = [
    { key: 'external_id', label: 'External ID', required: true, description: "ERP's unique identifier" },
    { key: 'company_name', label: 'Company Name', required: true, description: 'Company/business name' },
    { key: 'contact_name', label: 'Contact Name', required: true, description: 'Primary contact person' },
    { key: 'email', label: 'Email', required: true, description: 'Contact email address' },
    { key: 'contact_phone', label: 'Phone', required: false, description: 'Contact phone number' },
    { key: 'active', label: 'Active', required: false, description: 'Account status (boolean)' }
  ]

  connect() {
    this.erpProductFields = []
    this.erpCustomerFields = []
  }

  toggleEnabled() {
    if (this.enabledToggleTarget.checked) {
      this.settingsPanelTarget.classList.remove("d-none")
    } else {
      this.settingsPanelTarget.classList.add("d-none")
    }
  }

  changeAdapter() {
    const adapterType = this.adapterSelectTarget.value
    if (adapterType) {
      this.credentialsCardTarget.classList.remove("d-none")
    } else {
      this.credentialsCardTarget.classList.add("d-none")
    }
  }

  async testConnection(event) {
    event.preventDefault()

    const button = this.testButtonTarget
    const result = this.testResultTarget

    button.disabled = true
    button.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Testing...'
    result.innerHTML = ''

    try {
      const response = await fetch(this.testConnectionUrl, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
      })

      const data = await response.json()

      if (data.success) {
        result.innerHTML = '<span class="text-success"><i class="fa-solid fa-check-circle"></i> Connection successful!</span>'
      } else {
        result.innerHTML = `<span class="text-danger"><i class="fa-solid fa-times-circle"></i> ${data.error || 'Connection failed'}</span>`
      }
    } catch (error) {
      result.innerHTML = '<span class="text-danger"><i class="fa-solid fa-times-circle"></i> Connection test failed</span>'
    } finally {
      button.disabled = false
      button.innerHTML = '<i class="fa-solid fa-wifi"></i> Test Connection'
    }
  }

  async fetchSample(event) {
    event.preventDefault()

    const button = this.fetchSampleButtonTarget
    const result = this.fetchSampleResultTarget

    button.disabled = true
    button.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Fetching...'
    result.innerHTML = ''

    try {
      // Gather current credentials from the form
      const credentials = this.gatherCredentials()

      const response = await fetch(this.fetchSampleUrl, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ credentials })
      })

      const data = await response.json()

      if (data.success) {
        result.innerHTML = '<span class="text-success"><i class="fa-solid fa-check-circle"></i> Sample data fetched successfully!</span>'

        // Store ERP fields and render mapping tables
        if (data.products && data.products.fields) {
          this.erpProductFields = data.products.fields
          this.renderProductMappingTable()
          this.productsMappingSectionTarget.classList.remove('d-none')
        } else if (data.products_error) {
          result.innerHTML += `<br><span class="text-warning"><i class="fa-solid fa-exclamation-triangle"></i> Products: ${data.products_error}</span>`
        }

        if (data.customers && data.customers.fields) {
          this.erpCustomerFields = data.customers.fields
          this.renderCustomerMappingTable()
          this.customersMappingSectionTarget.classList.remove('d-none')
        } else if (data.customers_error) {
          result.innerHTML += `<br><span class="text-warning"><i class="fa-solid fa-exclamation-triangle"></i> Customers: ${data.customers_error}</span>`
        }
      } else {
        result.innerHTML = `<span class="text-danger"><i class="fa-solid fa-times-circle"></i> ${data.error || 'Failed to fetch sample data'}</span>`
      }
    } catch (error) {
      result.innerHTML = '<span class="text-danger"><i class="fa-solid fa-times-circle"></i> Failed to fetch sample data</span>'
      console.error('Fetch sample error:', error)
    } finally {
      button.disabled = false
      button.innerHTML = '<i class="fa-solid fa-download"></i> Fetch Sample Data'
    }
  }

  gatherCredentials() {
    const form = this.element.closest('form') || this.element
    const credentials = {}

    // Find all credential inputs in the form
    const credentialInputs = form.querySelectorAll('[name^="erp_configuration[credentials]"]')
    credentialInputs.forEach(input => {
      // Extract the key from the name: erp_configuration[credentials][key]
      const match = input.name.match(/erp_configuration\[credentials\]\[([^\]]+)\]/)
      if (match && !input.name.includes('field_mappings')) {
        credentials[match[1]] = input.value
      }
    })

    return credentials
  }

  renderProductMappingTable() {
    const tbody = this.productsMappingBodyTarget
    tbody.innerHTML = ''

    this.constructor.productFields.forEach(field => {
      const row = this.createMappingRow(field, this.erpProductFields, 'products')
      tbody.appendChild(row)
    })
  }

  renderCustomerMappingTable() {
    const tbody = this.customersMappingBodyTarget
    tbody.innerHTML = ''

    this.constructor.customerFields.forEach(field => {
      const row = this.createMappingRow(field, this.erpCustomerFields, 'customers')
      tbody.appendChild(row)
    })
  }

  createMappingRow(nodalField, erpFields, entityType) {
    const row = document.createElement('tr')

    // Get current mapping from hidden input
    const hiddenInput = this.findHiddenInput(entityType, nodalField.key)
    const currentMapping = hiddenInput ? hiddenInput.value : ''

    // Find sample value for currently mapped field
    const sampleValue = this.getSampleValue(erpFields, currentMapping)

    row.innerHTML = `
      <td>
        <strong>${nodalField.label}</strong>
        <br><small class="text-muted">${nodalField.description}</small>
      </td>
      <td>
        ${nodalField.required ? '<span class="badge bg-danger">Required</span>' : '<span class="badge bg-secondary">Optional</span>'}
      </td>
      <td>
        <select class="form-select form-select-sm"
                data-entity="${entityType}"
                data-nodal-field="${nodalField.key}"
                data-action="change->erp-settings#updateMapping">
          <option value="">-- Select ERP field --</option>
          ${erpFields.map(f => `
            <option value="${f.key}" ${f.key === currentMapping ? 'selected' : ''}>
              ${f.key} (${f.type})
            </option>
          `).join('')}
        </select>
      </td>
      <td>
        <code class="sample-value" data-entity="${entityType}" data-nodal-field="${nodalField.key}">
          ${sampleValue || '-'}
        </code>
      </td>
    `

    return row
  }

  findHiddenInput(entityType, fieldKey) {
    const targets = entityType === 'products' ? this.productMappingTargets : this.customerMappingTargets
    return targets.find(input => input.dataset.field === fieldKey)
  }

  getSampleValue(erpFields, fieldKey) {
    if (!fieldKey) return null
    const field = erpFields.find(f => f.key === fieldKey)
    return field ? field.value : null
  }

  updateMapping(event) {
    const select = event.target
    const entityType = select.dataset.entity
    const nodalField = select.dataset.nodalField
    const erpField = select.value

    // Update hidden input
    const hiddenInput = this.findHiddenInput(entityType, nodalField)
    if (hiddenInput) {
      hiddenInput.value = erpField
    }

    // Update sample value display
    const erpFields = entityType === 'products' ? this.erpProductFields : this.erpCustomerFields
    const sampleValue = this.getSampleValue(erpFields, erpField)

    const sampleDisplay = select.closest('tr').querySelector('.sample-value')
    if (sampleDisplay) {
      sampleDisplay.textContent = sampleValue || '-'
    }
  }

  get testConnectionUrl() {
    const path = window.location.pathname
    return path.replace(/\/edit$/, '/test_connection')
  }

  get fetchSampleUrl() {
    const path = window.location.pathname
    return path.replace(/\/edit$/, '/fetch_sample')
  }
}
