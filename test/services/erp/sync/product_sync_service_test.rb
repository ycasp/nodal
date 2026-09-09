require "test_helper"

module Erp
  module Sync
    class ProductSyncServiceTest < ActiveSupport::TestCase
      def setup
        @org = Organisation.create!(name: "Supplier Test Org")
        # allocate skips the full sync setup (adapter/erp_configuration/sync_log);
        # apply_product_supplier is pure logic and depends on none of it.
        @service = ProductSyncService.allocate
      end

      test "fills supplier when the product has none" do
        product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000)
        @service.send(:apply_product_supplier, product, { supplier: "ACME" })
        assert_equal "ACME", product.reload.supplier
      end

      test "strips surrounding whitespace from the ERP value" do
        product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000)
        @service.send(:apply_product_supplier, product, { supplier: "  ACME Lda.  " })
        assert_equal "ACME Lda.", product.reload.supplier
      end

      test "never overwrites a supplier already set by hand" do
        product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, supplier: "Manual")
        @service.send(:apply_product_supplier, product, { supplier: "FromERP" })
        assert_equal "Manual", product.reload.supplier
      end

      test "ignores blank or missing ERP supplier" do
        product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000)
        @service.send(:apply_product_supplier, product, { supplier: "   " })
        @service.send(:apply_product_supplier, product, {})
        assert_nil product.reload.supplier
      end
    end
  end
end
