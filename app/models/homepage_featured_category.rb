class HomepageFeaturedCategory < ApplicationRecord
  belongs_to :organisation
  belongs_to :category

  acts_as_list scope: :organisation_id

  validates :category_id, uniqueness: { scope: :organisation_id }
  validate :same_organisation

  private

  def same_organisation
    return unless organisation.present? && category.present?

    if organisation_id != category.organisation_id
      errors.add(:base, "Category must belong to the same organisation")
    end
  end
end
