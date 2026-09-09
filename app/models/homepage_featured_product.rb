class HomepageFeaturedProduct < ApplicationRecord
  belongs_to :organisation
  belongs_to :product

  acts_as_list scope: :organisation_id

  validates :product_id, uniqueness: { scope: :organisation_id }
  validate :same_organisation

  private

  def same_organisation
    return unless organisation.present? && product.present?

    if organisation_id != product.organisation_id
      errors.add(:base, "Product must belong to the same organisation")
    end
  end
end
