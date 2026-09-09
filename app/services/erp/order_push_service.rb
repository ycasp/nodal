module Erp
  # Pushes a single placed order to the configured ERP adapter. Handles
  # state transitions (pending → syncing → synced|failed), idempotency,
  # and error capture. Callers are expected to short-circuit on obvious
  # no-ops (org disabled, order already synced, attempts exhausted) — this
  # service still validates defensively.
  class OrderPushService
    Result = Struct.new(:success?, :order, :external_id, :error, :idempotent, keyword_init: true)

    IDEMPOTENCY_PREFIX = "NODAL".freeze

    def initialize(order:)
      @order = order
      @organisation = order.organisation
      @erp_config = @organisation.erp_configuration
    end

    def call
      return skip("ERP disabled or not configured") unless @erp_config&.can_sync_orders?
      return skip("Order not placed") unless @order.placed?
      return skip("Order already synced") if @order.push_synced?

      # Recorded, not merely refused. Both of these are about this order and
      # mean it will not reach the ERP without someone stepping in — leaving it
      # sitting at `pending` with no reason made it look like it was still on
      # its way, and the back office had no way to tell the difference.
      return refuse("Push attempts exhausted") if @order.push_exhausted?
      return refuse("Customer has no external_id") if @order.customer&.external_id.blank?

      adapter = @erp_config.adapter
      return skip("Adapter does not support push") unless adapter&.supports_push?

      @order.update!(
        push_status: "syncing",
        push_attempts: @order.push_attempts + 1,
        last_pushed_at: Time.current
      )

      response = adapter.push_order(serialize_order)

      if response[:success]
        mark_synced(response[:external_id])
        Result.new(
          success?: true,
          order: @order,
          external_id: response[:external_id],
          idempotent: response[:idempotent] || false
        )
      else
        mark_failed(response[:error] || "Unknown adapter error")
        Result.new(success?: false, order: @order, error: response[:error])
      end
    rescue StandardError => e
      mark_failed(e.message)
      Result.new(success?: false, order: @order, error: e.message)
    end

    private

    # A no-op that says nothing about this particular order — the org has no ERP
    # configured, the order is a draft, it is already synced. Nothing to record.
    def skip(reason)
      Result.new(success?: false, order: @order, error: reason)
    end

    # A refusal that is about this order. It goes on the record, so the order
    # never sits in a state that suggests it is still queued when it is not.
    def refuse(reason)
      mark_failed(reason)
      Result.new(success?: false, order: @order, error: reason)
    end

    def mark_synced(external_id)
      @order.update!(
        external_id: external_id,
        external_source: @erp_config.adapter_type,
        push_status: "synced",
        last_pushed_at: Time.current,
        sync_error: nil
      )
    end

    def mark_failed(error_message)
      @order.update!(
        push_status: "failed",
        sync_error: error_message.to_s.truncate(2000),
        last_pushed_at: Time.current
      )
    end

    def serialize_order
      {
        idempotency_key: idempotency_key,
        customer_external_id: @order.customer.external_id,
        delivery_date: @order.receive_on&.iso8601,
        notes: @order.notes.to_s[0, 255].presence,
        items: @order.order_items.includes(:product, :product_variant).map { |item| serialize_item(item) }
      }
    end

    def serialize_item(item)
      discount = item.discount_percentage.to_f
      gross_unit_price = item.price.to_f
      net_unit_price = (gross_unit_price * (1.0 - discount)).round(4)

      {
        product_code: product_code_for(item),
        quantity: item.quantity,
        unit_price: net_unit_price
      }
    end

    def product_code_for(item)
      item.product_variant&.external_id.presence ||
        item.product_variant&.sku.presence ||
        item.product&.sku
    end

    def idempotency_key
      "#{IDEMPOTENCY_PREFIX}:#{@order.order_number}"
    end
  end
end
