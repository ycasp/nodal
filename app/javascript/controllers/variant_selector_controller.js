import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "variantId", "price", "originalPrice", "sku", "stock", "addToCart", "image", "mainPrice", "discountBadge", "quantity"]
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
    outOfStockText: { type: String, default: "Out of Stock" }
  }

  connect() {
    this.selectedVariant = null
    this.originalImageUrl = this.hasImageTarget ? this.imageTarget.src : null
    this.updateSelection()
    this.updateTotal()
  }

  change() {
    this.updateSelection()
    this.updateTotal()
  }

  updateTotal() {
    const quantity = this.hasQuantityTarget ? parseInt(this.quantityTarget.value) || this.minQuantityValue || 1 : this.minQuantityValue || 1

    let priceCents
    if (this.selectedVariant) {
      priceCents = this.selectedVariant.has_discount ? this.selectedVariant.final_price_cents : this.selectedVariant.price_cents
    } else {
      priceCents = this.defaultHasDiscountValue ? this.defaultFinalPriceCentsValue : this.defaultPriceCentsValue
    }

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
    if (!this.hasMainPriceTarget || !variant) return

    if (variant.has_discount) {
      // Show discounted price in green
      this.mainPriceTarget.textContent = this.formatPrice(variant.final_price_cents)
      this.mainPriceTarget.classList.remove("text-primary")
      this.mainPriceTarget.classList.add("text-success")

      // Show original price with strikethrough
      if (this.hasOriginalPriceTarget) {
        this.originalPriceTarget.textContent = this.formatPrice(variant.price_cents)
        this.originalPriceTarget.classList.remove("d-none")
      }

      // Show discount badge
      if (this.hasDiscountBadgeTarget) {
        this.discountBadgeTarget.textContent = `-${variant.discount_percentage}% OFF`
        this.discountBadgeTarget.classList.remove("d-none")
      }
    } else {
      // Show regular price
      this.mainPriceTarget.textContent = this.formatPrice(variant.price_cents)
      this.mainPriceTarget.classList.remove("text-success")
      this.mainPriceTarget.classList.add("text-primary")

      // Hide original price and badge
      if (this.hasOriginalPriceTarget) {
        this.originalPriceTarget.classList.add("d-none")
      }
      if (this.hasDiscountBadgeTarget) {
        this.discountBadgeTarget.classList.add("d-none")
      }
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

    // Note: Price and discount display is handled by updateMainPrice()

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
          this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-check me-1 text-success"></i> ${this.inStockTextValue}`
        } else {
          this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-xmark me-1 text-danger"></i> ${this.outOfStockTextValue}`
        }
      } else {
        this.stockTarget.innerHTML = `<i class="fa-solid fa-circle-check me-1 text-success"></i> ${this.inStockTextValue}`
      }
    }

    // Update image if variant has specific photo, otherwise revert to original
    if (this.hasImageTarget) {
      this.imageTarget.src = variant.photo_url || this.originalImageUrl
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
