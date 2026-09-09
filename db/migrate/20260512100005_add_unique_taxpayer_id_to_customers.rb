class AddUniqueTaxpayerIdToCustomers < ActiveRecord::Migration[7.1]
  # Non-unique partial index — added for lookup performance (NIF-first
  # reconciliation in Erp::Sync::CustomerSyncService and the model-level
  # uniqueness validation both query by taxpayer_id frequently).
  #
  # The uniqueness CONSTRAINT was deferred: prod still carries a handful of
  # PHC-side duplicates (same NIF, different external_id) that need to be
  # merged on the PHC side. Once those are cleaned and the
  # CustomerSyncService dup-skip safeguard has been running for a while,
  # a follow-up migration can promote this to a unique index.
  def change
    add_index :customers,
              [:organisation_id, :taxpayer_id],
              where: "taxpayer_id IS NOT NULL AND taxpayer_id <> ''",
              name: "index_customers_on_org_id_taxpayer_id"
  end
end
