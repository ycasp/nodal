import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "variantId", "price", "originalPrice", "sku", "stock", "addToCart", "image", "mainPrice", "quantity"]
  static values = {
    variants: Array,
    currencySymbol: String,
    defaultPriceCents: Number,
    minQuantity: Number,
    defaultSku: String
  }

  connect() {
    this.selectedVariant = null
    this.updateSelection()
    this.updateTotal()
  }

  change() {
    this.updateSelection()
    this.updateTotal()
  }

  updateTotal() {
    const quantity = this.hasQuantityTarget ? parseInt(this.quantityTarget.value) || this.minQuantityValue || 1 : this.minQuantityValue || 1
    const priceCents = this.selectedVariant?.price_cents || this.defaultPriceCentsValue

    if (priceCents && this.hasPriceTarget) {
      const total = priceCents * quantity
      this.priceTarget.textContent = this.formatPrice(total)
    }
  }

  updateSelection() {
    const selectedValues = this.getSelectedValues()
    const variant = this.findMatchingVariant(selectedValues)

    if (variant) {
      this.selectedVariant = variant
      this.updateDisplay(variant)
      this.updateMainPrice(variant)
      this.enableAddToCart(variant)
    } else {
      this.selectedVariant = null
      this.disableAddToCart()
    }
  }

  updateMainPrice(variant) {
    if (this.hasMainPriceTarget && variant) {
      this.mainPriceTarget.textContent = this.formatPrice(variant.price_cents)
    }
  }

  getSelectedValues() {
    const values = []
    this.selectTargets.forEach(select => {
      if (select.value) {
        values.push(parseInt(select.value))
      }
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
    // Update variant ID hidden field
    if (this.hasVariantIdTarget) {
      this.variantIdTarget.value = variant.id
    }

    // Note: Price display is handled by updateTotal() which includes quantity calculation

    // Update original price if different from base
    if (this.hasOriginalPriceTarget && variant.original_price_cents !== variant.price_cents) {
      this.originalPriceTarget.textContent = this.formatPrice(variant.original_price_cents)
      this.originalPriceTarget.classList.remove("d-none")
    } else if (this.hasOriginalPriceTarget) {
      this.originalPriceTarget.classList.add("d-none")
    }

    // Update SKU (fall back to parent product SKU if variant has none)
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

    // Update stock status
    if (this.hasStockTarget) {
      if (variant.track_stock) {
        if (variant.in_stock) {
          this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-check me-1 text-success"></i> In Stock (${variant.stock_quantity})`
        } else {
          this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-xmark me-1 text-danger"></i> Out of Stock`
        }
      } else {
        this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-check me-1 text-success"></i> In Stock`
      }
    }

    // Update image if variant has specific photo
    if (this.hasImageTarget && variant.photo_url) {
      this.imageTarget.src = variant.photo_url
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
