require "test_helper"

module Automations
  class OutOfStockDigestTest < ActiveSupport::TestCase
    setup do
      @organisation = Organisation.create!(
        name: "Test Org",
        slug: "test-org-#{SecureRandom.hex(4)}",
        currency: "EUR",
        tax_rate: 0.23,
        low_stock_threshold: 5
      )
      @period = 7.days.ago..Time.current
    end

    def product_with(supplier: nil, has_variants: false)
      Product.create!(
        organisation: @organisation,
        name: "Product #{SecureRandom.hex(4)}",
        slug: "product-#{SecureRandom.hex(4)}",
        unit_price: 1000,
        supplier: supplier,
        has_variants: has_variants
      )
    end

    def rupture(variant, occurred_at: 1.day.ago, from: 4)
      StockEvent.create!(
        organisation: @organisation,
        product_variant: variant,
        kind: StockEvent::OUT_OF_STOCK,
        from_quantity: from,
        to_quantity: 0,
        occurred_at: occurred_at
      )
    end

    def report(filters = {})
      OutOfStockDigest.new(organisation: @organisation, filters: filters)
    end

    test "lists the references that ran out in the period" do
      variant = product_with.default_variant
      variant.update!(sku: "ABC-1")
      rupture(variant)

      rows = report.rows(@period)
      assert_equal 1, rows.size
      assert_equal "ABC-1", rows.first[:sku]
      assert_equal 4, rows.first[:last_qty]
    end

    test "ignores ruptures outside the period" do
      rupture(product_with.default_variant, occurred_at: 30.days.ago)
      assert_empty report.rows(@period)
    end

    test "ignores back_in_stock and low_stock events" do
      variant = product_with.default_variant
      StockEvent.create!(organisation: @organisation, product_variant: variant,
                         kind: StockEvent::BACK_IN_STOCK, from_quantity: 0, to_quantity: 3,
                         occurred_at: 1.day.ago)
      StockEvent.create!(organisation: @organisation, product_variant: variant,
                         kind: StockEvent::LOW_STOCK, from_quantity: 20, to_quantity: 3,
                         occurred_at: 1.day.ago)

      assert_empty report.rows(@period)
    end

    test "a reference that flapped several times appears once" do
      variant = product_with.default_variant
      rupture(variant, occurred_at: 5.days.ago, from: 9)
      rupture(variant, occurred_at: 2.days.ago, from: 3)

      rows = report.rows(@period)
      assert_equal 1, rows.size
      assert_equal 3, rows.first[:last_qty], "keeps the most recent rupture"
    end

    test "the supplier filter narrows the list" do
      mine   = product_with(supplier: "Fornecedor A").default_variant
      theirs = product_with(supplier: "Fornecedor B").default_variant
      mine.update!(sku: "A-1")
      rupture(mine)
      rupture(theirs)

      rows = report(suppliers: [ "Fornecedor A" ]).rows(@period)
      assert_equal [ "A-1" ], rows.map { |r| r[:sku] }
    end

    test "several suppliers can be selected at once" do
      a = product_with(supplier: "Fornecedor A").default_variant
      b = product_with(supplier: "Fornecedor B").default_variant
      c = product_with(supplier: "Fornecedor C").default_variant
      a.update!(sku: "A-1")
      b.update!(sku: "B-1")
      [ a, b, c ].each { |v| rupture(v) }

      rows = report(suppliers: [ "Fornecedor A", "Fornecedor B" ]).rows(@period)
      assert_equal %w[A-1 B-1], rows.map { |r| r[:sku] }.sort
    end

    test "several categories can be selected at once" do
      cat_a = Category.create!(organisation: @organisation, name: "Anéis", slug: "a-#{SecureRandom.hex(3)}")
      cat_b = Category.create!(organisation: @organisation, name: "Brincos", slug: "b-#{SecureRandom.hex(3)}")
      in_a = product_with
      in_b = product_with
      out  = product_with
      CategoryProduct.create!(category: cat_a, product: in_a)
      CategoryProduct.create!(category: cat_b, product: in_b)
      in_a.default_variant.update!(sku: "A-1")
      in_b.default_variant.update!(sku: "B-1")
      [ in_a, in_b, out ].each { |p| rupture(p.default_variant) }

      rows = report(category_ids: [ cat_a.id, cat_b.id ]).rows(@period)
      assert_equal %w[A-1 B-1], rows.map { |r| r[:sku] }.sort
    end

    test "an empty supplier list means all suppliers" do
      a = product_with(supplier: "Fornecedor A").default_variant
      a.update!(sku: "A-1")
      rupture(a)

      assert_equal 1, report(suppliers: [ "" ]).rows(@period).size
    end

    test "the category filter narrows the list" do
      category = Category.create!(organisation: @organisation, name: "Anéis", slug: "aneis-#{SecureRandom.hex(3)}")
      inside   = product_with
      outside  = product_with
      CategoryProduct.create!(category: category, product: inside)
      inside.default_variant.update!(sku: "IN-1")
      rupture(inside.default_variant)
      rupture(outside.default_variant)

      rows = report(category_ids: [ category.id ]).rows(@period)
      assert_equal [ "IN-1" ], rows.map { |r| r[:sku] }
    end

    test "the placeholder variant of a variable product is excluded" do
      product = product_with(has_variants: true)
      rupture(product.default_variant)

      assert_empty report.rows(@period), "the base variant of a variable product isn't a sellable unit"
    end

    test "another organisation's ruptures never leak in" do
      other_org = Organisation.create!(name: "Other", slug: "other-#{SecureRandom.hex(4)}",
                                       currency: "EUR", tax_rate: 0.23)
      other_product = Product.create!(organisation: other_org, name: "X",
                                      slug: "x-#{SecureRandom.hex(4)}", unit_price: 500)
      StockEvent.create!(organisation: other_org, product_variant: other_product.default_variant,
                         kind: StockEvent::OUT_OF_STOCK, from_quantity: 2, to_quantity: 0,
                         occurred_at: 1.day.ago)

      assert_empty report.rows(@period)
    end
  end
end
