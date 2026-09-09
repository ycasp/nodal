import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="checkout"
export default class extends Controller {
    static targets = [
        "shippingAmount", "totalAmount", "totalLabel", "totalRow",
        "shippingNotice", "shippingAddressSection",
        "shippingSelector", "sameAsBillingOption", "dateLabel",
        "newShippingAddressForm", "deliveryShippingCost", "dateField"
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
        earliestDate: String,
        shippingDeferred: Boolean,
        shippingPendingLabel: String,
        totalLabel: String,
        totalWithoutShippingLabel: String
    }

    connect() {
        this.toggleShippingAddress()
        if (this.shippingDeferredValue) this.updateTotal()
    }

    qualifiesForFreeShipping() {
        return this.freeShippingEnabledValue &&
               this.freeShippingThresholdValue > 0 &&
               this.subtotalValue >= this.freeShippingThresholdValue
    }

    // Mirrors Order#deferred_shipping? — pickup and free shipping are settled
    // here and now even when the organisation prices shipping at dispatch.
    shippingIsPending(isPickup, qualifiesForFree) {
        return this.shippingDeferredValue && !isPickup && !qualifiesForFree
    }

    updateTotal() {
        const isPickup = document.getElementById("delivery_method_pickup").checked
        const qualifiesForFree = this.qualifiesForFreeShipping()
        const pending = this.shippingIsPending(isPickup, qualifiesForFree)
        const shipping = isPickup || qualifiesForFree || pending ? 0 : this.shippingCostValue
        const total = this.subtotalValue + this.taxValue + shipping

        if (this.hasShippingAmountTarget) {
            this.shippingAmountTarget.textContent = pending
                ? this.shippingPendingLabelValue
                : this.formatCurrency(shipping)
        }
        if (this.hasTotalAmountTarget) this.totalAmountTarget.textContent = this.formatCurrency(total)
        if (this.hasTotalLabelTarget) {
            this.totalLabelTarget.textContent = pending
                ? this.totalWithoutShippingLabelValue
                : this.totalLabelValue
        }
        if (this.hasShippingNoticeTarget) this.shippingNoticeTarget.classList.toggle("d-none", !pending)
        if (this.hasTotalRowTarget) {
            this.totalRowTarget.classList.toggle("mb-2", pending)
            this.totalRowTarget.classList.toggle("mb-4", !pending)
        }
    }

    toggleShippingAddress() {
        const isPickup = document.getElementById("delivery_method_pickup").checked
        const sameAsBillingEl = document.getElementById("same_as_billing")
        const sameAsBilling = sameAsBillingEl ? sameAsBillingEl.checked : false

        // Whole shipping card hides only when pickup is selected.
        if (this.hasShippingAddressSectionTarget) {
            this.shippingAddressSectionTarget.style.display = isPickup ? "none" : "block"
        }

        // Inner shipping selector hides when shipping to billing address —
        // the checkbox stays visible so the customer can flip it back.
        if (this.hasShippingSelectorTarget) {
            this.shippingSelectorTarget.style.display = sameAsBilling ? "none" : "block"
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
