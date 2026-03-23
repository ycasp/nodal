module Erp
  module Sync
    class OrderExportService < BaseSyncService
      protected

      def entity_type
        'orders'
      end

      def perform_sync
        unless adapter.supports_push?
          raise Erp::ApiError, "Adapter '#{adapter.adapter_name}' does not support pushing orders"
        end

        exportable_orders.each do |order|
          export_order(order)
        end
      end

      private

      def exportable_orders
        organisation.orders.placed.where(external_id: nil)
      end

      def export_order(order)
        unless order.customer&.external_id.present?
          sync_log.increment_failed!(
            order.order_number,
            "Customer '#{order.customer&.company_name}' has no external_id — sync customers first"
          )
          return
        end

        order_data = serialize_order(order)
        adapter.push_order(order_data)

        # Record the external_id on the order after successful push
        order.update!(
          external_id: order.order_number,
          external_source: external_source,
          last_synced_at: Time.current,
          sync_error: nil
        )

        sync_log.increment_created!
      rescue StandardError => e
        order.update_column(:sync_error, e.message) if order.persisted?
        sync_log.increment_failed!(order.order_number, e.message)
      end

      def serialize_order(order)
        {
          'order_number' => order.order_number,
          'customer_external_id' => order.customer.external_id,
          'placed_at' => order.placed_at&.iso8601,
          'status' => order.status,
          'payment_status' => order.payment_status,
          'delivery_method' => order.delivery_method,
          'total_amount' => order.total_amount.to_f,
          'tax_amount' => (order.tax_amount || order.calculated_tax).to_f,
          'shipping_amount' => (order.shipping_amount || order.calculated_shipping).to_f,
          'grand_total' => order.grand_total.to_f,
          'notes' => order.notes,
          'items' => order.order_items.map { |item| serialize_order_item(item) }
        }
      end

      def serialize_order_item(item)
        {
          'product_external_id' => item.product&.external_id,
          'product_sku' => item.product&.sku,
          'product_name' => item.product&.name,
          'variant_external_id' => item.product_variant&.external_id,
          'variant_sku' => item.product_variant&.sku,
          'quantity' => item.quantity,
          'unit_price' => item.unit_price_cents.to_f / 100,
          'discount_percentage' => item.discount_percentage,
          'total_price' => item.total_price.to_f
        }
      end
    end
  end
end
