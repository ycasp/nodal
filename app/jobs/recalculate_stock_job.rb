class RecalculateStockJob < ApplicationJob
  queue_as :default

  def perform(organisation_id)
    organisation = Organisation.find(organisation_id)
    service = StockRulesService.new(organisation)

    organisation.product_variants.where(track_stock: true).find_each do |variant|
      service.apply_to_variant(variant)
    end

    organisation.products.find_each do |product|
      service.recalculate_product_availability(product)
    end
  end
end
