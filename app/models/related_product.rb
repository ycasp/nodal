class RelatedProduct < ApplicationRecord
  belongs_to :product
  belongs_to :related_product, class_name: "Product"

  acts_as_list scope: :product_id

  validates :product_id, uniqueness: { scope: :related_product_id, message: "already has this related product" }
  validate :same_organisation
  validate :not_self_referential

  # A related-products link is a statement about a pair, so it is stored in both
  # directions: A → B always has B → A alongside it. RelatedProductsFetcher only
  # ever reads `product_id = self`, so without the second row the relationship is
  # invisible from the other product's side, in the back office and in the shop.
  scope :without_mirror, -> {
    where(
      "NOT EXISTS (SELECT 1 FROM related_products AS mirrors" \
      " WHERE mirrors.product_id = related_products.related_product_id" \
      " AND mirrors.related_product_id = related_products.product_id)"
    )
  }

  # Adds the missing half of every one-sided link. Returns what it did (or would
  # do, when dry_run). A pair that cannot be mirrored — a link left over from
  # before the same-organisation rule, say — is reported rather than raised, so
  # one bad row cannot stop the rest.
  def self.create_missing_mirrors!(scope: all, dry_run: true)
    created = []
    skipped = []

    # Snapshotting first keeps the work deterministic: the rows being written
    # live in the table being read.
    scope.without_mirror.pluck(:product_id, :related_product_id).each do |product_id, related_product_id|
      mirror = new(product_id: related_product_id, related_product_id: product_id)

      if mirror.valid?
        created << [ related_product_id, product_id ]
        mirror.save! unless dry_run
      else
        skipped << { pair: [ product_id, related_product_id ], reason: mirror.errors.full_messages.join(", ") }
      end
    end

    { created: created, skipped: skipped }
  end

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
