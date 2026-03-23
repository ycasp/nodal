import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="checkout"
export default class extends Controller {
    static targets = [
        "shippingAmount", "totalAmount", "shippingAddressSection",
        "sameAsShippingOption", "dateLabel", "newShippingAddressForm",
        "billingAddressFields", "deliveryShippingCost", "dateField"
    ]
    static values = {
        subtotal: Number,
        tax: Number,
        shippingCost: Number,
        currencySymbol: String,
        freeShippingThreshold: Number,
        freeShippingEnabled: Boolean,
        deliveryLabel: String,
        pickupLabel: String,
        deliveryDays: Array,
        earliestDate: String
    }

    connect() {
        this.toggleShippingAddress()
        this.toggleBillingAddress()
    }

    qualifiesForFreeShipping() {
        return this.freeShippingEnabledValue &&
               this.freeShippingThresholdValue > 0 &&
               this.subtotalValue >= this.freeShippingThresholdValue
    }

    updateTotal() {
        const isPickup = document.getElementById("delivery_method_pickup").checked
        const qualifiesForFree = this.qualifiesForFreeShipping()
        const shipping = isPickup || qualifiesForFree ? 0 : this.shippingCostValue
        const total = this.subtotalValue + this.taxValue + shipping

        this.shippingAmountTarget.textContent = this.formatCurrency(shipping)
        this.totalAmountTarget.textContent = this.formatCurrency(total)
    }

    toggleShippingAddress() {
        const isPickup = document.getElementById("delivery_method_pickup").checked

        if (this.hasShippingAddressSectionTarget) {
            this.shippingAddressSectionTarget.style.display = isPickup ? "none" : "block"
        }

        if (this.hasSameAsShippingOptionTarget) {
            this.sameAsShippingOptionTarget.style.display = isPickup ? "none" : "flex"
        }

        if (this.hasDateLabelTarget) {
            this.dateLabelTarget.textContent = isPickup ? this.pickupLabelValue : this.deliveryLabelValue
        }
    }

    toggleNewShippingAddress(event) {
        if (this.hasNewShippingAddressFormTarget) {
            const isNew = event.target.value === "new"
            this.newShippingAddressFormTarget.style.display = isNew ? "block" : "none"
        }
    }

    toggleBillingAddress() {
        const sameAsShipping = document.getElementById("same_as_shipping")
        if (sameAsShipping && this.hasBillingAddressFieldsTarget) {
            this.billingAddressFieldsTarget.style.display = sameAsShipping.checked ? "none" : "block"
        }
    }

    validateDate() {
        if (!this.hasDateFieldTarget || !this.hasDeliveryDaysValue) return

        const selected = this.dateFieldTarget.value
        if (!selected) return

        const date = new Date(selected + "T00:00:00")
        const dayOfWeek = date.getDay()

        if (!this.deliveryDaysValue.includes(dayOfWeek)) {
            this.dateFieldTarget.value = this.earliestDateValue
        }
    }

    formatCurrency(cents) {
        const amount = (cents / 100).toFixed(2)
        const symbol = this.currencySymbolValue || '€'
        return `${symbol}${amount}`
    }
}
