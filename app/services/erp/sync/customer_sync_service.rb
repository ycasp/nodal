module Erp
  module Sync
    class CustomerSyncService < BaseSyncService
      protected

      def entity_type
        'customers'
      end

      GC_INTERVAL = 500

      def perform_sync
        count = 0
        adapter.each_customer do |customer_data|
          sync_customer(customer_data)
          count += 1
          GC.start if (count % GC_INTERVAL).zero?
        end
      end

      private

      def sync_customer(data)
        external_id = data[:external_id]

        unless external_id.present?
          sync_log.increment_failed!('unknown', 'Missing external_id')
          return
        end

        customer = find_or_initialize_customer(external_id, data[:taxpayer_id], data[:email])

        # Returned nil means we deliberately skipped — another already-synced
        # customer in this org has the same NIF, and re-importing would
        # recreate a duplicate that an admin had previously cleaned up.
        if customer.nil?
          sync_log.increment_processed!
          Rails.logger.info(
            "[ERP sync] Skipped duplicate NIF for external_id=#{external_id} " \
            "(taxpayer_id=#{data[:taxpayer_id]}) — another synced customer in " \
            "org #{organisation.id} already holds this NIF."
          )
          return
        end

        was_new = customer.new_record?

        # Customer holds only ERP-owned fields after the customer/login split
        # (auth + personal preferences live on CustomerUser, which is never
        # synced from ERP). So ERP wins, always — no identity guard.
        update_customer_attributes(customer, data, was_new)

        if was_new || customer.changed?
          changes_snapshot = customer.changes
          if customer.save
            customer.mark_synced!(source: external_source)
            if was_new
              record_changes(external_id, 'created', customer)
              sync_log.increment_created!
            else
              record_changes(external_id, 'updated', customer, changes_snapshot)
              sync_log.increment_updated!
            end
          else
            sync_log.increment_failed!(external_id, customer.errors.full_messages.join(', '))
            return
          end
        else
          sync_log.increment_processed!
        end

        # Always run for both new and existing customers, regardless of
        # identity guard. Lenient: per-address failures are logged but
        # don't fail the customer sync.
        sync_addresses(customer, data)

        # Mirror the empresa's contact fields into a stub CustomerUser so
        # that ERP-supplied identity has somewhere usable to land. Once a
        # login has been invited it leaves ERP control and is no longer
        # touched here — see #mirror_customer_user_stub for the rule.
        mirror_customer_user_stub(customer)
      rescue StandardError => e
        sync_log.increment_failed!(data[:external_id], e.message)
      end

      # Keeps a single non-invited "stub" CustomerUser in sync with the
      # Customer (empresa) record. The stub is the seed login the BO can
      # invite later. Rule: ERP only touches logins that have NOT been
      # invited yet — once invitation_sent_at is set on any login, the
      # whole set is human-managed and we leave it alone.
      def mirror_customer_user_stub(customer)
        # If any login has already been invited, hands off entirely.
        return if customer.customer_users.where.not(invitation_sent_at: nil).exists?

        attrs = {
          email: customer.email,
          contact_name: customer.contact_name,
          contact_phone: customer.contact_phone,
          active: customer.active?
        }

        # Skip if we have nothing useful to mirror — an empty stub with
        # no email can't be invited by the BO anyway.
        return if attrs[:email].blank?

        stub = customer.customer_users.first
        if stub
          stub.update(attrs)
        else
          customer.customer_users.create!(
            attrs.merge(organisation_id: customer.organisation_id)
          )
        end
      rescue StandardError => e
        Rails.logger.warn(
          "[ERP sync] customer_user stub mirror failed for " \
          "customer external_id=#{customer.external_id}: #{e.message}"
        )
      end

      # Syncs billing + shipping addresses for a customer.
      # Billing: ERP overwrites the existing record (or creates one).
      # Shipping: never replaces; only adds when the ERP-provided address
      # doesn't match any existing active shipping by content fingerprint.
      # Failures on either side are logged but don't break customer sync.
      def sync_addresses(customer, data)
        if data[:billing_address].present?
          begin
            sync_billing_address(customer, data[:billing_address])
          rescue StandardError => e
            Rails.logger.warn("[ERP sync] billing address failed for customer external_id=#{customer.external_id}: #{e.message}")
          end
        end

        if data[:shipping_address].present?
          begin
            sync_shipping_address(customer, data[:shipping_address])
          rescue StandardError => e
            Rails.logger.warn("[ERP sync] shipping address failed for customer external_id=#{customer.external_id}: #{e.message}")
          end
        end
      end

      def sync_billing_address(customer, attrs)
        billing = customer.billing_address_with_archived ||
                  customer.build_billing_address_with_archived(address_type: "billing")

        # Reset every known address field before applying ERP values so
        # unmapped fields don't keep stale data (e.g. a street_nr from a
        # one-off CSV import when the ERP only exposes a combined street).
        reset_attrs = { street_name: nil, street_nr: nil, postal_code: nil, city: nil, country: nil }

        billing.assign_attributes(
          reset_attrs.merge(attrs).merge(
            address_type: "billing",
            external_source: external_source,
            last_synced_at: Time.current,
            active: true
          )
        )
        billing.save! if billing.changed?
      end

      def sync_shipping_address(customer, attrs)
        new_fp = Address.fingerprint_for(
          street_name: attrs[:street_name],
          street_nr: attrs[:street_nr],
          postal_code: attrs[:postal_code],
          city: attrs[:city],
          country: attrs[:country]
        )

        existing_match = customer.shipping_addresses_with_archived
                                 .active
                                 .find { |a| a.fingerprint == new_fp }
        return if existing_match

        customer.shipping_addresses_with_archived.create!(
          attrs.merge(
            address_type: "shipping",
            external_source: external_source,
            last_synced_at: Time.current,
            active: true
          )
        )
      end

      def find_or_initialize_customer(external_id, taxpayer_id, email)
        # 1. Exact match by external_id + source (already-synced case)
        customer = organisation.customers.find_by(
          external_id: external_id,
          external_source: external_source
        )
        return customer if customer

        # 2. Match by NIF (taxpayer_id) — canonical fiscal key in PT B2B, and
        # the safest reconciliation key for rep-created customers awaiting
        # their first ERP id. Only reconciles unsynced rows (external_id blank).
        if taxpayer_id.present?
          customer = organisation.customers.where(external_id: nil)
                                           .where("LOWER(taxpayer_id) = ?", taxpayer_id.downcase)
                                           .first
          if customer
            customer.external_id = external_id
            customer.external_source = external_source
            return customer
          end
        end

        # 3. Fallback: match by email (still useful when NIF is missing or
        # was typed differently between Nodal and PHC).
        if email.present?
          customer = organisation.customers.find_by(email: email)
          if customer && customer.external_id.blank?
            customer.external_id = external_id
            customer.external_source = external_source
            return customer
          end
        end

        # 4. Before creating a brand-new customer, guard against re-introducing
        # duplicates that an admin previously cleaned up in Nodal. If another
        # customer in this org is ALREADY synced with the same NIF, the PHC is
        # carrying two records for the same fiscal entity — we keep the one
        # Nodal already has and skip this import. Caller treats nil as skip.
        if taxpayer_id.present?
          existing_synced = organisation.customers
                                        .where.not(external_id: nil)
                                        .where("LOWER(taxpayer_id) = ?", taxpayer_id.downcase)
                                        .exists?
          return nil if existing_synced
        end

        # 5. Create new customer
        organisation.customers.new(
          external_id: external_id,
          external_source: external_source
        )
      end

      def update_customer_attributes(customer, data, _is_new)
        customer.assign_attributes(
          company_name: data[:company_name],
          contact_name: data[:contact_name],
          contact_phone: data[:phone],
          taxpayer_id: data[:taxpayer_id],
          active: data[:active]
        )

        # `customers.email` is NOT NULL (default ""), and the adapter drops the
        # key altogether when the ERP column is NULL — passing nil straight
        # through would hit a NotNullViolation. A blank from the ERP means "no
        # data", not "clear it", so an address already typed in the BO survives:
        # it is the seed for inviting a login later.
        customer.email = data[:email].to_s if data[:email].present? || customer.email.blank?
      end

      def record_changes(external_id, action, customer, changes_snapshot = nil)
        changes = if action == 'created'
          {
            company_name: customer.company_name,
            contact_name: customer.contact_name,
            email: customer.email
          }
        else
          changes_snapshot || customer.changes
        end

        sync_log.add_change(external_id, 'Customer', action, changes)
      end
    end
  end
end
