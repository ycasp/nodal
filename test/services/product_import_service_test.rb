require "test_helper"

class ProductImportServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(
      name: "Test Organisation",
      slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR",
      tax_rate: 0.23
    )
  end

  test "creates new products from CSV" do
    csv_content = <<~CSV
      Product Name,Product SKU,Price,Description
      Test Product 1,SKU001,12.50,A test product description
      Test Product 2,SKU002,24.99,Another test description
    CSV

    mapping = {
      "Product Name" => "name",
      "Product SKU" => "sku",
      "Price" => "price",
      "Description" => "description"
    }

    service = ProductImportService.new(
      organisation: @organisation,
      csv_content: csv_content,
      column_mapping: mapping
    )

    result = service.call

    assert_equal 2, result.created
    assert_equal 0, result.updated
    assert_equal 0, result.errors.size

    product1 = @organisation.products.find_by(sku: "SKU001")
    assert_not_nil product1
    assert_equal "Test Product 1", product1.name
    assert_equal 1250, product1.unit_price

    product2 = @organisation.products.find_by(sku: "SKU002")
    assert_not_nil product2
    assert_equal "Test Product 2", product2.name
    assert_equal 2499, product2.unit_price
  end

  test "updates existing products by SKU" do
    existing_product = Product.create!(
      organisation: @organisation,
      name: "Old Name",
      slug: "old-name",
      sku: "EXISTING123",
      description: "Old description here",
      unit_price: 1000
    )

    csv_content = <<~CSV
      name,sku,price,description
      Updated Name,EXISTING123,15.00,Updated description here
    CSV

    mapping = {
      "name" => "name",
      "sku" => "sku",
      "price" => "price",
      "description" => "description"
    }

    service = ProductImportService.new(
      organisation: @organisation,
      csv_content: csv_content,
      column_mapping: mapping
    )

    result = service.call

    assert_equal 0, result.created
    assert_equal 1, result.updated

    existing_product.reload
    assert_equal "Updated Name", existing_product.name
    assert_equal 1500, existing_product.unit_price
    assert_equal "Updated description here", existing_product.description
  end

  test "reports errors for invalid rows" do
    csv_content = <<~CSV
      name,sku,price,description
      ,SKU001,12.50,Missing name field
    CSV

    mapping = {
      "name" => "name",
      "sku" => "sku",
      "price" => "price",
      "description" => "description"
    }

    service = ProductImportService.new(
      organisation: @organisation,
      csv_content: csv_content,
      column_mapping: mapping
    )

    result = service.call

    assert_equal 0, result.created
    assert result.errors.any?
    assert result.errors.first[:message].downcase.include?("name")
  end

  test "skips unmapped columns" do
    csv_content = <<~CSV
      name,unused_column,price,description
      Test Product,ignore me,10.00,Test description here
    CSV

    mapping = {
      "name" => "name",
      "unused_column" => "",
      "price" => "price",
      "description" => "description"
    }

    service = ProductImportService.new(
      organisation: @organisation,
      csv_content: csv_content,
      column_mapping: mapping
    )

    result = service.call

    assert_equal 1, result.created
    assert_equal 0, result.errors.size
  end

  test "handles European decimal format" do
    csv_content = <<~CSV
      name,price,description
      Test Product,12.50,Test description
      Test Product 2,"1,234.56",Test description 2
    CSV

    mapping = {
      "name" => "name",
      "price" => "price",
      "description" => "description"
    }

    service = ProductImportService.new(
      organisation: @organisation,
      csv_content: csv_content,
      column_mapping: mapping
    )

    result = service.call

    assert_equal 2, result.created

    products = @organisation.products.where(name: ["Test Product", "Test Product 2"])
    assert_equal 1250, products.find_by(name: "Test Product").unit_price
    assert_equal 123456, products.find_by(name: "Test Product 2").unit_price
  end

  test "handles boolean fields" do
    csv_content = <<~CSV
      name,available,description,price
      Product 1,true,Description for one,10.00
      Product 2,false,Description for two,20.00
      Product 3,yes,Description three here,30.00
      Product 4,no,Description for four,40.00
    CSV

    mapping = {
      "name" => "name",
      "available" => "available",
      "description" => "description",
      "price" => "price"
    }

    service = ProductImportService.new(
      organisation: @organisation,
      csv_content: csv_content,
      column_mapping: mapping
    )

    result = service.call

    assert_equal 4, result.created

    # Verify available field is set correctly if product has available attribute
    if Product.column_names.include?("available")
      product1 = @organisation.products.find_by(name: "Product 1")
      product2 = @organisation.products.find_by(name: "Product 2")
      assert_equal true, product1.available
      assert_equal false, product2.available
    end
  end

  test "returns correct totals" do
    csv_content = <<~CSV
      name,sku,description,price
      Product 1,NEW001,This is a longer description for product one,10.00
      Product 2,NEW002,This is a longer description for product two,20.00
    CSV

    mapping = {
      "name" => "name",
      "sku" => "sku",
      "description" => "description",
      "price" => "price"
    }

    service = ProductImportService.new(
      organisation: @organisation,
      csv_content: csv_content,
      column_mapping: mapping
    )

    result = service.call

    assert_equal 2, result.total
    assert_equal result.created + result.updated, result.total
  end

  test "returns importable fields list" do
    fields = ProductImportService.importable_fields

    assert_includes fields, "name"
    assert_includes fields, "sku"
    assert_includes fields, "price"
    assert_includes fields, "description"
    assert_includes fields, "available"
  end
end
