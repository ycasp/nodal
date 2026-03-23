class RelatedProduct < ApplicationRecord
  belongs_to :product
  belongs_to :related_product, class_name: "Product"

  acts_as_list scope: :product_id

  validates :product_id, uniqueness: { scope: :related_product_id, message: "already has this related product" }
  validate :same_organisation
  validate :not_self_referential

  private

  def same_organisation
    return unless product.present? && related_product.present?

    if product.organisation_id != related_product.organisation_id
      errors.add(:base, "Products must belong to the same organisation")
    end
  end

  def not_self_referential
    return unless product.present? && related_product.present?

    if product_id == related_product_id
      errors.add(:base, "A product cannot be related to itself")
    end
  end
end
