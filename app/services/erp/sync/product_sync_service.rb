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

        product = find_or_initialize_product(external_id)
        was_new = product.new_record?

        update_product_attributes(product, data)

        if product.save
          product.mark_synced!(source: external_source)

          if was_new
            sync_log.increment_created!
          else
            sync_log.increment_updated!
          end
        else
          sync_log.increment_failed!(external_id, product.errors.full_messages.join(', '))
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
        product.assign_attributes(
          name: data[:name],
          sku: data[:sku],
          description: data[:description],
          unit_price: data[:unit_price_cents],
          available: data[:available]
        )

        generate_slug(product) if product.new_record?
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
