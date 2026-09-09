import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "group", "button", "variantId", "price", "originalPrice", "sku", "stock", "addToCart", "image", "zoomImage", "mainPrice", "discountBadge", "quantity"]
  // When present, the product-pricing controller owns the header price, the
  // estimated total and the live unlock tracker; the selector just feeds it the
  // chosen variant. Without it (no conditional discount) the selector renders
  // the price itself, as before.
  static outlets = ["product-pricing"]
  static values = {
    variants: Array,
    currencySymbol: String,
    defaultPriceCents: Number,
    defaultFinalPriceCents: Number,
    defaultHasDiscount: Boolean,
    defaultDiscountPercentage: Number,
    minQuantity: Number,
    defaultSku: String,
    inStockText: { type: String, default: "In Stock" },
    outOfStockText: { type: String, default: "Out of Stock" },
    displayPrice: { type: String, default: "" },
    displayPriceOriginal: { type: String, default: "" }
  }

  connect() {
    this.selectedVariant = null
    this.originalImageUrl = this.hasImageTarget ? this.imageTarget.src : null
    // Store original options for dropdown selects
    this.originalOptions = this.selectTargets.map(select => {
      return Array.from(select.options).map(opt => ({
        value: opt.value,
        text: opt.textContent,
        selected: opt.selected,
        color: opt.dataset.color
      }))
    })
    this.filterAvailableOptions()
    this.updateSelection()
    this.updateTotal()
  }

  // The product-pricing tracker may connect after us; re-apply the current
  // selection so it gets the right variant immediately.
  productPricingOutletConnected() {
    this.updateSelection()
    this.updateTotal()
  }

  // Called when a dropdown changes
  change() {
    this.filterAvailableOptions()
    this.updateSelection()
    this.updateTotal()
  }

  // Called when a button/swatch is clicked
  selectOption(event) {
    const button = event.currentTarget
    const group = button.closest("[data-variant-selector-target='group']")

    if (button.classList.contains("active")) {
      button.classList.remove("active")
    } else {
      group.querySelectorAll("[data-variant-selector-target='button']").forEach(btn => {
        btn.classList.remove("active")
      })
      button.classList.add("active")
    }

    this.filterAvailableOptions()
    this.updateSelection()
    this.updateTotal()
  }

  filterAvailableOptions() {
    // Collect all attribute selectors (both dropdowns and button groups)
    const selectors = this._getAllSelectors()

    selectors.forEach((current, currentIndex) => {
      // Get selected values from all OTHER selectors
      const otherSelections = []
      selectors.forEach((other, otherIndex) => {
        if (otherIndex === currentIndex) return
        const val = this._getSelectorValue(other)
        if (val) otherSelections.push(val)
      })

      // Find compatible values
      const compatibleValueIds = new Set()
      const allValueIds = this._getSelectorValueIds(current)

      this.variantsValue.forEach(variant => {
        const matchesOthers = otherSelections.every(selectedId =>
          variant.attribute_value_ids.includes(selectedId)
        )
        if (matchesOthers) {
          variant.attribute_value_ids.forEach(valueId => {
            if (allValueIds.includes(valueId)) {
              compatibleValueIds.add(valueId)
            }
          })
        }
      })

      // Apply filtering
      if (current.type === "select") {
        this._filterSelect(current.element, compatibleValueIds)
      } else {
        this._filterButtonGroup(current.element, compatibleValueIds)
      }
    })
  }

  _getAllSelectors() {
    const selectors = []

    // Visible dropdown selects
    this.selectTargets.forEach(select => {
      if (!select.classList.contains("d-none")) {
        selectors.push({ type: "select", element: select })
      }
    })

    // Button groups
    this.groupTargets.forEach(group => {
      selectors.push({ type: "group", element: group })
    })

    return selectors
  }

  _getSelectorValue(selector) {
    if (selector.type === "select") {
      return selector.element.value ? parseInt(selector.element.value) : null
    } else {
      const activeBtn = selector.element.querySelector("[data-variant-selector-target='button'].active")
      return activeBtn ? parseInt(activeBtn.dataset.valueId) : null
    }
  }

  _getSelectorValueIds(selector) {
    if (selector.type === "select") {
      const selectIndex = this.selectTargets.indexOf(selector.element)
      return this.originalOptions[selectIndex]
        .filter(opt => opt.value)
        .map(opt => parseInt(opt.value))
    } else {
      return Array.from(
        selector.element.querySelectorAll("[data-variant-selector-target='button']")
      ).map(btn => parseInt(btn.dataset.valueId))
    }
  }

  _filterSelect(select, compatibleValueIds) {
    const currentValue = select.value
    Array.from(select.options).forEach(option => {
      if (!option.value) return
      const valueId = parseInt(option.value)
      const isCompatible = compatibleValueIds.has(valueId)
      option.disabled = !isCompatible
      option.style.display = isCompatible ? "" : "none"
    })

    if (currentValue && !compatibleValueIds.has(parseInt(currentValue))) {
      const firstCompatible = Array.from(select.options).find(
        opt => opt.value && !opt.disabled
      )
      select.value = firstCompatible ? firstCompatible.value : ""
    }
  }

  _filterButtonGroup(group, compatibleValueIds) {
    group.querySelectorAll("[data-variant-selector-target='button']").forEach(btn => {
      const valueId = parseInt(btn.dataset.valueId)
      const isCompatible = compatibleValueIds.has(valueId)
      btn.disabled = !isCompatible
      if (!isCompatible) {
        btn.classList.add("opacity-25")
        if (btn.classList.contains("active")) {
          btn.classList.remove("active")
        }
      } else {
        btn.classList.remove("opacity-25")
      }
    })
  }

  updateTotal() {
    if (this.hasProductPricingOutlet) return // product-pricing owns the total

    const quantity = this.hasQuantityTarget ? parseInt(this.quantityTarget.value) || this.minQuantityValue || 1 : this.minQuantityValue || 1
    const isVariable = this.variantsValue && this.variantsValue.length > 0

    let priceCents
    if (this.selectedVariant) {
      priceCents = this.selectedVariant.has_discount ? this.selectedVariant.final_price_cents : this.selectedVariant.price_cents
    } else if (isVariable) {
      // Variable product, no variant selected — running total is meaningless yet.
      if (this.hasPriceTarget) this.priceTarget.textContent = ""
      return
    } else {
      priceCents = this.defaultHasDiscountValue ? this.defaultFinalPriceCentsValue : this.defaultPriceCentsValue
    }

    if (priceCents && this.hasPriceTarget) {
      const total = priceCents * quantity
      this.priceTarget.textContent = ` · ${this.formatPrice(total)}`
    }
  }

  updateSelection() {
    const selectedValues = this.getSelectedValues()
    const variant = this.findMatchingVariant(selectedValues)

    if (variant) {
      this.selectedVariant = variant
      this.updateDisplay(variant)
      this.enableAddToCart(variant)
      if (this.hasProductPricingOutlet) {
        this.productPricingOutlet.applyVariant(variant.id) // owns price/total/tracker
      } else {
        this.updateMainPrice(variant)
      }
    } else {
      this.selectedVariant = null
      if (this.hasProductPricingOutlet) this.productPricingOutlet.applyVariant(null)
      this.showPriceRange()
      this.disableAddToCart()
    }
  }

  updateMainPrice(variant) {
    if (!this.hasMainPriceTarget || !variant) return

    if (variant.has_discount) {
      this.mainPriceTarget.textContent = this.formatPrice(variant.final_price_cents)
      this.mainPriceTarget.classList.remove("text-primary")
      this.mainPriceTarget.classList.add("text-success")

      if (this.hasOriginalPriceTarget) {
        this.originalPriceTarget.textContent = this.formatPrice(variant.price_cents)
        this.originalPriceTarget.classList.remove("d-none")
      }

      if (this.hasDiscountBadgeTarget) {
        this.discountBadgeTarget.textContent = `-${variant.discount_percentage}% OFF`
        this.discountBadgeTarget.classList.remove("d-none")
      }
    } else {
      this.mainPriceTarget.textContent = this.formatPrice(variant.price_cents)
      this.mainPriceTarget.classList.remove("text-success")
      this.mainPriceTarget.classList.add("text-primary")

      if (this.hasOriginalPriceTarget) {
        this.originalPriceTarget.classList.add("d-none")
      }
      if (this.hasDiscountBadgeTarget) {
        this.discountBadgeTarget.classList.add("d-none")
      }
    }
  }

  showPriceRange() {
    const hasBaseDiscount = this.defaultHasDiscountValue && this.displayPriceOriginalValue

    if (this.hasMainPriceTarget && this.displayPriceValue) {
      this.mainPriceTarget.textContent = this.displayPriceValue
      if (hasBaseDiscount) {
        this.mainPriceTarget.classList.remove("text-primary")
        this.mainPriceTarget.classList.add("text-success")
      } else {
        this.mainPriceTarget.classList.remove("text-success")
        this.mainPriceTarget.classList.add("text-primary")
      }
    }
    if (this.hasOriginalPriceTarget) {
      if (hasBaseDiscount) {
        this.originalPriceTarget.textContent = this.displayPriceOriginalValue
        this.originalPriceTarget.classList.remove("d-none")
      } else {
        this.originalPriceTarget.classList.add("d-none")
      }
    }
    if (this.hasDiscountBadgeTarget) {
      if (hasBaseDiscount && this.defaultDiscountPercentageValue) {
        this.discountBadgeTarget.textContent = `-${this.defaultDiscountPercentageValue}% OFF`
        this.discountBadgeTarget.classList.remove("d-none")
      } else {
        this.discountBadgeTarget.classList.add("d-none")
      }
    }
    if (this.hasPriceTarget) {
      this.priceTarget.textContent = ""
    }
  }

  getSelectedValues() {
    const values = []

    // From dropdown selects
    this.selectTargets.forEach(select => {
      if (select.value) {
        values.push(parseInt(select.value))
      }
    })

    // From button groups
    this.groupTargets.forEach(group => {
      const activeBtn = group.querySelector("[data-variant-selector-target='button'].active")
      if (activeBtn) {
        values.push(parseInt(activeBtn.dataset.valueId))
      }
    })

    // From hidden single-value inputs
    this.element.querySelectorAll("input[data-single-attribute-value]").forEach(input => {
      values.push(parseInt(input.dataset.singleAttributeValue))
    })

    return values.sort((a, b) => a - b)
  }

  findMatchingVariant(selectedValues) {
    if (selectedValues.length === 0) return null

    return this.variantsValue.find(variant => {
      const variantValues = variant.attribute_value_ids.sort((a, b) => a - b)
      return JSON.stringify(variantValues) === JSON.stringify(selectedValues)
    })
  }

  updateDisplay(variant) {
    if (this.hasVariantIdTarget) {
      this.variantIdTarget.value = variant.id
    }

    if (this.hasSkuTarget) {
      const effectiveSku = variant.sku || this.defaultSkuValue
      if (effectiveSku) {
        this.skuTarget.textContent = effectiveSku
        this.skuTarget.closest(".sku-container")?.classList.remove("d-none")
      } else {
        this.skuTarget.textContent = "-"
        this.skuTarget.closest(".sku-container")?.classList.add("d-none")
      }
    }

    if (this.hasStockTarget) {
      if (variant.purchasable) {
        this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-check me-1 text-success"></i> ${this.inStockTextValue}`
      } else if (variant.track_stock && !variant.in_stock) {
        this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-xmark me-1 text-danger"></i> ${this.outOfStockTextValue}`
      } else {
        this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-check me-1 text-success"></i> ${this.inStockTextValue}`
      }
    }

    if (this.hasImageTarget) {
      const imageUrl = variant.photo_url || this.originalImageUrl
      this.imageTarget.src = imageUrl
      if (this.hasZoomImageTarget) {
        this.zoomImageTarget.src = imageUrl
      }
    }
  }

  enableAddToCart(variant) {
    if (this.hasAddToCartTarget) {
      if (variant.purchasable) {
        this.addToCartTarget.disabled = false
        this.addToCartTarget.classList.remove("btn-secondary")
        this.addToCartTarget.classList.add("btn-primary")
      } else {
        this.disableAddToCart()
      }
    }
  }

  disableAddToCart() {
    if (this.hasAddToCartTarget) {
      this.addToCartTarget.disabled = true
      this.addToCartTarget.classList.remove("btn-primary")
      this.addToCartTarget.classList.add("btn-secondary")
    }
  }

  formatPrice(cents) {
    const amount = (cents / 100).toFixed(2)
    return `${this.currencySymbolValue}${amount}`
  }
}
