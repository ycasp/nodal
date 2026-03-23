module Erp
  module Sync
    class CustomerSyncService < BaseSyncService
      protected

      def entity_type
        'customers'
      end

      def perform_sync
        customers_data = adapter.fetch_customers

        customers_data.each do |customer_data|
          sync_customer(customer_data)
        end
      end

      private

      def sync_customer(data)
        external_id = data[:external_id]

        unless external_id.present?
          sync_log.increment_failed!('unknown', 'Missing external_id')
          return
        end

        customer = find_or_initialize_customer(external_id, data[:email])
        was_new = customer.new_record?

        update_customer_attributes(customer, data, was_new)

        if was_new || customer.changed?
          if customer.save
            customer.mark_synced!(source: external_source)

            if was_new
              sync_log.increment_created!
            else
              sync_log.increment_updated!
            end
          else
            sync_log.increment_failed!(external_id, customer.errors.full_messages.join(', '))
          end
        else
          sync_log.increment_processed!
        end
      rescue StandardError => e
        sync_log.increment_failed!(data[:external_id], e.message)
      end

      def find_or_initialize_customer(external_id, email)
        # First try to find by external_id
        customer = organisation.customers.find_by(
          external_id: external_id,
          external_source: external_source
        )

        return customer if customer

        # If not found by external_id, try by email (for linking existing customers)
        if email.present?
          customer = organisation.customers.find_by(email: email)
          if customer && customer.external_id.blank?
            customer.external_id = external_id
            customer.external_source = external_source
            return customer
          end
        end

        # Create new customer
        organisation.customers.new(
          external_id: external_id,
          external_source: external_source
        )
      end

      def update_customer_attributes(customer, data, is_new)
        customer.assign_attributes(
          company_name: data[:company_name],
          contact_name: data[:contact_name],
          email: data[:email],
          contact_phone: data[:phone],
          taxpayer_id: data[:taxpayer_id],
          active: data[:active]
        )

        if is_new
          set_temporary_password(customer)
        end
      end

      def set_temporary_password(customer)
        temp_password = SecureRandom.hex(12)
        customer.password = temp_password
        customer.password_confirmation = temp_password
      end
    end
  end
end
