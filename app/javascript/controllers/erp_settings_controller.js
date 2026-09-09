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
    "ordersMappingSection",
    "ordersMappingBody",
    "orderStaticSection",
    "productMapping",
    "customerMapping",
    "orderMapping",
    "adapterCredentials",
    "productSyncMode",
    "filterInput",
    "filterResult"
  ]

  // Nodal field definitions
  static productFields = [
    { key: 'external_id', label: 'External ID', required: true, description: "ERP's unique identifier" },
    { key: 'name', label: 'Name', required: true, description: 'Product name' },
    { key: 'sku', label: 'SKU', required: false, description: 'Stock keeping unit' },
    { key: 'description', label: 'Description', required: false, description: 'Product description' },
    { key: 'unit_price', label: 'Unit Price', required: false, description: 'Price (will be converted to cents)' },
    { key: 'available', label: 'Available', required: false, description: 'Availability status (boolean)' },
    { key: 'stock_quantity', label: 'Stock Quantity', required: false, description: 'Stock quantity (integer)' },
    { key: 'supplier', label: 'Supplier', required: false, description: 'Supplier / brand — fill-if-blank: only set when Nodal field is empty' }
  ]

  static customerFields = [
    { key: 'external_id', label: 'External ID', required: true, description: "ERP's unique identifier" },
    { key: 'company_name', label: 'Company Name', required: true, description: 'Company/business name' },
    { key: 'contact_name', label: 'Contact Name', required: true, description: 'Primary contact person' },
    { key: 'email', label: 'Email', required: true, description: 'Contact email address' },
    { key: 'contact_phone', label: 'Phone', required: false, description: 'Contact phone number' },
    { key: 'taxpayer_id', label: 'NIF', required: false, description: 'Tax identification number' },
    { key: 'active', label: 'Active', required: false, description: 'Account status (boolean)' },
    { key: 'billing_street_name', label: 'Billing Street', required: false, description: 'Billing address — street name (overwrites on every sync)' },
    { key: 'billing_street_nr', label: 'Billing Number', required: false, description: 'Billing address — street number' },
    { key: 'billing_postal_code', label: 'Billing Postal Code', required: false, description: 'Billing address — postal code' },
    { key: 'billing_city', label: 'Billing City', required: false, description: 'Billing address — city' },
    { key: 'billing_country', label: 'Billing Country', required: false, description: 'Billing address — country' },
    { key: 'shipping_street_name', label: 'Shipping Street', required: false, description: 'Shipping address — street name (sync only adds when the address differs from existing ones)' },
    { key: 'shipping_street_nr', label: 'Shipping Number', required: false, description: 'Shipping address — street number' },
    { key: 'shipping_postal_code', label: 'Shipping Postal Code', required: false, description: 'Shipping address — postal code' },
    { key: 'shipping_city', label: 'Shipping City', required: false, description: 'Shipping address — city' },
    { key: 'shipping_country', label: 'Shipping Country', required: false, description: 'Shipping address — country' }
  ]

  static orderFields = [
    { key: 'order_number', label: 'Order Number', required: true, description: 'ERP-assigned order number column (auto-filled on insert)' },
    { key: 'line_number', label: 'Line Number', required: false, description: 'Line number column within the order (auto-filled on insert)' },
    { key: 'customer_external_id', label: 'Customer ID', required: true, description: "Customer's ERP ID column" },
    { key: 'product_code', label: 'Product Code', required: true, description: 'Product/variant code column (per line)' },
    { key: 'quantity', label: 'Quantity', required: true, description: 'Line quantity column' },
    { key: 'unit_price', label: 'Unit Price', required: true, description: 'Line net unit price column' },
    { key: 'delivery_date', label: 'Delivery Date', required: false, description: 'Expected delivery date column' },
    { key: 'notes', label: 'Notes', required: false, description: 'Order notes column' },
    { key: 'idempotency_key', label: 'Idempotency Key', required: true, description: 'Column that stores the Nodal reference (e.g. OBSERVACOES2) — used to avoid duplicate pushes' },
    { key: 'location_id', label: 'Location', required: false, description: 'Delivery location/branch column (e.g. LOCAL_ID)' }
  ]

  static orderItemFields = []

  connect() {
    this.erpProductFields = []
    this.erpCustomerFields = []
    this.erpOrderFields = []
    this.erpOrderItemFields = []

    // Disable inputs in hidden adapter credential panels so they don't submit
    const activeAdapter = this.adapterSelectTarget.value
    this.adapterCredentialsTargets.forEach(panel => {
      if (panel.dataset.adapterType !== activeAdapter) {
        panel.querySelectorAll("input").forEach(input => { input.disabled = true })
      }
    })
  }

  toggleEnabled() {
    if (this.enabledToggleTarget.checked) {
      this.settingsPanelTarget.classList.remove("d-none")
    } else {
      this.settingsPanelTarget.classList.add("d-none")
    }
  }

  toggleOrderStatic(event) {
    if (!this.hasOrderStaticSectionTarget) return
    if (event.target.checked) {
      this.orderStaticSectionTarget.classList.remove("d-none")
    } else {
      this.orderStaticSectionTarget.classList.add("d-none")
    }
  }

  changeAdapter() {
    const adapterType = this.adapterSelectTarget.value
    if (adapterType) {
      this.credentialsCardTarget.classList.remove("d-none")
    } else {
      this.credentialsCardTarget.classList.add("d-none")
    }

    // Show/hide the correct credentials panel and disable hidden inputs
    this.adapterCredentialsTargets.forEach(panel => {
      const isActive = panel.dataset.adapterType === adapterType
      panel.classList.toggle("d-none", !isActive)
      panel.querySelectorAll("input").forEach(input => {
        input.disabled = !isActive
      })
    })
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
      const adapterType = this.adapterSelectTarget.value

      const response = await fetch(this.fetchSampleUrl, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ credentials, adapter_type: adapterType })
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

        // Order mapping tables (for adapters that support push)
        if (data.orders && data.orders.fields) {
          this.erpOrderFields = data.orders.fields
          this.renderOrderMappingTable()
          this.ordersMappingSectionTarget.classList.remove('d-none')
        } else if (data.orders_error) {
          result.innerHTML += `<br><span class="text-warning"><i class="fa-solid fa-exclamation-triangle"></i> Orders: ${data.orders_error}</span>`
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

  renderOrderMappingTable() {
    const tbody = this.ordersMappingBodyTarget
    tbody.innerHTML = ''

    this.constructor.orderFields.forEach(field => {
      const row = this.createMappingRow(field, this.erpOrderFields, 'orders')
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
    let targets
    switch (entityType) {
      case 'products':
        targets = this.productMappingTargets
        break
      case 'customers':
        targets = this.customerMappingTargets
        break
      case 'orders':
        targets = this.orderMappingTargets
        break
      default:
        return null
    }
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
    let erpFields
    switch (entityType) {
      case 'products':
        erpFields = this.erpProductFields
        break
      case 'customers':
        erpFields = this.erpCustomerFields
        break
      case 'orders':
        erpFields = this.erpOrderFields
        break
      case 'order_items':
        erpFields = this.erpOrderItemFields
        break
      default:
        erpFields = []
    }
    const sampleValue = this.getSampleValue(erpFields, erpField)

    const sampleDisplay = select.closest('tr').querySelector('.sample-value')
    if (sampleDisplay) {
      sampleDisplay.textContent = sampleValue || '-'
    }
  }

  confirmSyncMode(event) {
    const select = event.target
    if (select.value === 'full_sync') {
      const confirmed = confirm(
        'Full sync will create new products in Nodal for every product in your ERP that doesn\'t already exist. ' +
        'This can be dangerous if you manage product variants manually.\n\n' +
        'Are you sure you want to enable full sync?'
      )
      if (!confirmed) {
        select.value = 'update_only'
      }
    }
  }

  async testFilter(event) {
    event.preventDefault()

    const button = event.currentTarget
    const entityType = button.dataset.entityType

    const input = this.filterInputTargets.find(el => el.dataset.entityType === entityType)
    const result = this.filterResultTargets.find(el => el.dataset.entityType === entityType)
    if (!input || !result) return

    const originalHtml = button.innerHTML
    button.disabled = true
    button.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> A testar...'
    result.innerHTML = ''
    result.className = 'text-muted d-block mt-1'

    try {
      const response = await fetch(this.testFilterUrl, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ entity_type: entityType, filter: input.value })
      })

      const data = await response.json()

      if (data.success) {
        result.className = 'text-success d-block mt-1'
        result.innerHTML = `<i class="fa-solid fa-check-circle"></i> Filtro devolve <strong>${data.count.toLocaleString()}</strong> linha(s)`
      } else {
        result.className = 'text-danger d-block mt-1'
        result.innerHTML = `<i class="fa-solid fa-times-circle"></i> ${data.error || 'Erro ao testar filtro'}`
      }
    } catch (error) {
      result.className = 'text-danger d-block mt-1'
      result.innerHTML = '<i class="fa-solid fa-times-circle"></i> Falha no teste'
      console.error('Test filter error:', error)
    } finally {
      button.disabled = false
      button.innerHTML = originalHtml
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

  get testFilterUrl() {
    const path = window.location.pathname
    return path.replace(/\/edit$/, '/test_filter')
  }
}
