namespace :maintenance do
  desc "Fix stock consistency: align variant.available with actual stock levels and recalculate product.available"
  task fix_stock_consistency: :environment do
    Organisation.where(out_of_stock_strategy: %w[deactivate hide]).find_each do |org|
      puts "Processing organisation: #{org.name} (strategy: #{org.out_of_stock_strategy})"
      service = StockRulesService.new(org)

      # Fix variant available based on actual stock (only for tracked, non-manually-managed variants)
      fixed_variants = 0
      org.product_variants.where(track_stock: true).find_each do |v|
        correct_available = v.stock_quantity.to_i > 0
        if v.available != correct_available
          v.update_column(:available, correct_available)
          fixed_variants += 1
        end
      end
      puts "  Fixed #{fixed_variants} variant available flags"

      # Recalculate all product availability
      fixed_products = 0
      org.products.find_each do |product|
        any_available = product.product_variants.where(available: true).exists?
        if product.available != any_available
          product.update_column(:available, any_available)
          fixed_products += 1
        end
      end
      puts "  Fixed #{fixed_products} product available flags"
    end

    # Ensure all stock_policy values are valid
    invalid = ProductVariant.where.not(stock_policy: ProductVariant::STOCK_POLICIES).count
    puts "Variants with invalid stock_policy: #{invalid}" if invalid > 0

    puts "Done!"
  end
end
