module Erp
  module Sync
    class ProductSyncService < BaseSyncService
      protected

      def entity_type
        'products'
      end

      GC_INTERVAL = 500

      def perform_sync
        count = 0
        adapter.each_product do |product_data|
          sync_product(product_data)
          count += 1
          GC.start if (count % GC_INTERVAL).zero?
        end
      end

      private

      def sync_product(data)
        external_id = data[:external_id]

        unless external_id.present?
          sync_log.increment_failed!('unknown', 'Missing external_id')
          return
        end

        # 1. Find variant by external_id (primary match)
        variant = find_variant_by_external_id(external_id)

        # 2. Fallback: find variant by SKU
        if variant.nil?
          sku = data[:sku] || external_id
          variant = find_variant_by_sku(sku)
          if variant
            variant.update_columns(external_id: external_id, external_source: external_source)
          end
        end

        # 3. No match — create or skip
        if variant.nil?
          if update_only_mode?
            sync_log.increment_processed!
            return
          else
            variant = create_product_with_variant(data, external_id)
          end
        end

        sync_variant(variant, data)
      rescue StandardError => e
        sync_log.increment_failed!(data[:external_id], e.message)
      end

      def create_product_with_variant(data, external_id)
        product = organisation.products.new(
          name: data[:name] || external_id,
          description: data[:description],
          supplier: data[:supplier].to_s.strip.presence
        )
        generate_slug(product)
        product.save!

        variant = product.default_variant
        variant.update_columns(
          external_id: external_id,
          external_source: external_source
        )

        record_changes(external_id, 'Product', 'created', product)
        sync_log.increment_created!
        variant
      end

      # Fill-if-blank: set the product's supplier from the ERP only when Nodal
      # doesn't already have one. A manual value in the BO always wins.
      def apply_product_supplier(product, data)
        value = data[:supplier].to_s.strip
        return if value.blank? || product.supplier.present?

        product.update_column(:supplier, value)
      end

      def find_variant_by_external_id(external_id)
        ProductVariant.joins(:product)
                      .where(products: { organisation_id: organisation.id })
                      .find_by(external_id: external_id, external_source: external_source)
      end

      def find_variant_by_sku(sku)
        ProductVariant.joins(:product)
                      .where(products: { organisation_id: organisation.id })
                      .where.not(sku: [nil, ''])
                      .find_by(sku: sku)
      end

      def sync_variant(variant, data)
        update_variant_attributes(variant, data)
        attributes_changed = variant.changed?

        update_stock(variant, data) if data[:stock_quantity].present?

        # Supplier is product-level and Nodal-managed: the ERP only fills it in
        # when it's still blank, never overwriting a value set by hand.
        apply_product_supplier(variant.product, data)

        if variant.changed?
          action = attributes_changed ? 'updated' : 'stock_updated'
          record_changes(data[:external_id], 'ProductVariant', action, variant)
          if variant.save
            apply_stock_rules(variant) if data[:stock_quantity].present?
            variant.mark_synced!(source: external_source)

            if attributes_changed
              sync_log.increment_updated!
            else
              sync_log.increment_processed!
            end
          else
            sync_log.increment_failed!(data[:external_id], variant.errors.full_messages.join(', '))
          end
        else
          sync_log.increment_processed!
        end
      end

      def update_variant_attributes(variant, data)
        variant.name = data[:name] if data.key?(:name)
        variant.sku = data[:sku] if data.key?(:sku)
        variant.write_attribute(:unit_price_cents, data[:unit_price_cents]) if data.key?(:unit_price_cents)
        if data.key?(:available) && !organisation.deactivate_out_of_stock?
          variant.published = data[:available]
        end
      end

      def update_stock(variant, data)
        variant.stock_quantity = data[:stock_quantity]
        variant.track_stock = true if variant.new_record? || !variant.persisted?
      end

      def apply_stock_rules(variant)
        StockRulesService.new(organisation).apply_to_variant(variant)
      end

      def update_only_mode?
        erp_configuration.product_sync_mode != 'full_sync'
      end

      def record_changes(external_id, record_type, action, record)
        changes = if action == 'created'
          { name: record.respond_to?(:sku) ? record.name : record.name, sku: record.try(:sku) }
        else
          record.changes.transform_values { |old_val, new_val| [old_val, new_val] }
        end

        sync_log.add_change(external_id, record_type, action, changes)
      end

      def generate_slug(product)
        base_slug = product.name&.parameterize
        return unless base_slug.present?

        slug = base_slug
        counter = 1

        while organisation.products.where.not(id: product.id).exists?(slug: slug)
          slug = "#{base_slug}-#{counter}"
          counter += 1
        end

        product.slug = slug
      end
    end
  end
end
