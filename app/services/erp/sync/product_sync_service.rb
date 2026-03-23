module Erp
  module Sync
    class ProductSyncService < BaseSyncService
      protected

      def entity_type
        'products'
      end

      def perform_sync
        products_data = adapter.fetch_products

        products_data.each do |product_data|
          sync_product(product_data)
        end
      end

      private

      def sync_product(data)
        external_id = data[:external_id]

        unless external_id.present?
          sync_log.increment_failed!('unknown', 'Missing external_id')
          return
        end

        # 1. Try matching a product by external_id
        product = organisation.products.find_by(external_id: external_id, external_source: external_source)

        # 2. If no product match, try matching a variant by external_id
        if product.nil?
          variant = find_variant_by_external_id(external_id)
          if variant
            sync_variant(variant, data)
            return
          end
        end

        # 3. Fallback: try matching by SKU (for manually created products/variants)
        if product.nil?
          sku = data[:sku] || external_id
          variant = find_variant_by_sku(sku)
          if variant
            # Link to ERP for future syncs
            variant.update_columns(external_id: external_id, external_source: external_source)
            sync_variant(variant, data)
            return
          end

          product = organisation.products.find_by(sku: sku)
          if product
            # Link to ERP for future syncs
            product.update_columns(external_id: external_id, external_source: external_source)
          end
        end

        # 4. No match at all — handle per sync mode
        if product.nil?
          if update_only_mode?
            sync_log.increment_processed!
            return
          else
            product = find_or_initialize_product(external_id)
          end
        end

        was_new = product.new_record?
        update_product_attributes(product, data)

        if was_new || product.changed?
          record_changes(external_id, 'Product', was_new ? 'created' : 'updated', product) unless was_new
          if product.save
            update_variant_stock(product, data)
            product.mark_synced!(source: external_source)

            if was_new
              record_changes(external_id, 'Product', 'created', product)
              sync_log.increment_created!
            else
              sync_log.increment_updated!
            end
          else
            sync_log.increment_failed!(external_id, product.errors.full_messages.join(', '))
          end
        else
          # Product attributes unchanged, but still update stock
          update_variant_stock(product, data)
          sync_log.increment_processed!
        end
      rescue StandardError => e
        sync_log.increment_failed!(data[:external_id], e.message)
      end

      def find_or_initialize_product(external_id)
        organisation.products.find_or_initialize_by(
          external_id: external_id,
          external_source: external_source
        )
      end

      def update_product_attributes(product, data)
        product.name = data[:name] if data.key?(:name)
        product.sku = data[:sku] if data.key?(:sku)
        product.description = data[:description] if data.key?(:description)
        # Use write_attribute to bypass monetize wrapper and assign cents directly
        product.write_attribute(:unit_price, data[:unit_price_cents]) if data.key?(:unit_price_cents)
        # Skip available override when stock rules control availability
        if data.key?(:available) && !organisation.deactivate_out_of_stock?
          product.available = data[:available]
        end

        generate_slug(product) if product.new_record?
      end

      def update_variant_stock(product, data)
        return unless data[:stock_quantity].present?

        variant = product.default_variant
        return unless variant

        old_stock = variant.stock_quantity
        update_stock(variant, data)
        if variant.changed?
          record_changes(product.external_id, 'ProductVariant', 'stock_updated', variant)
        end
        variant.save!
        apply_stock_rules(variant)
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

        if variant.changed?
          action = attributes_changed ? 'updated' : 'stock_updated'
          record_changes(data[:external_id], 'ProductVariant', action, variant)
          if variant.save
            apply_stock_rules(variant) if data[:stock_quantity].present?
            variant.mark_synced!(source: external_source)

            if attributes_changed
              sync_log.increment_updated!
            else
              # Only stock changed, not product attributes
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
        # Skip available override when stock rules control availability
        if data.key?(:available) && !organisation.deactivate_out_of_stock?
          variant.available = data[:available]
        end
      end

      def update_stock(variant, data)
        variant.stock_quantity = data[:stock_quantity]
        # Only enable track_stock for new variants that haven't been explicitly configured
        variant.track_stock = true if variant.new_record? || !variant.persisted?
      end

      def apply_stock_rules(variant)
        return unless organisation.deactivate_out_of_stock?
        return unless variant.track_stock?

        # Update variant availability based on stock
        if variant.stock_quantity.to_i <= 0
          variant.update_column(:available, false) unless variant.available == false
        else
          variant.update_column(:available, true) unless variant.available == true
        end

        # Update parent product availability based on tracked variants
        product = variant.product
        tracked_variants = product.product_variants.where(track_stock: true)

        if tracked_variants.exists? && tracked_variants.where('stock_quantity > 0').none?
          product.update(available: false)
        elsif product.product_variants.where(available: true).exists?
          product.update(available: true)
        end
      end

      def update_only_mode?
        erp_configuration.product_sync_mode != 'full_sync'
      end

      def record_changes(external_id, record_type, action, record)
        changes = if action == 'created'
          { name: record.name, sku: record.sku }
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
