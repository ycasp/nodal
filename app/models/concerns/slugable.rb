module Slugable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, on: [:create, :update]

    private

    def source_attribute
      self.class.source_attribute || :name
    end

    def secondary_slug_attribute
      self.class.secondary_slug_attribute
    end

    def generate_slug
      base = send(source_attribute)&.to_s&.parameterize
      return if base.blank?

      # Append secondary attribute (e.g., SKU) if configured and present
      if secondary_slug_attribute && respond_to?(secondary_slug_attribute)
        secondary = send(secondary_slug_attribute)
        base = "#{base}-#{secondary.to_s.parameterize}" if secondary.present?
      end

      # Handle uniqueness collisions by appending a counter
      candidate = base
      counter = 1
      while self.class.where.not(id: id).exists?(slug: candidate)
        counter += 1
        candidate = "#{base}-#{counter}"
      end

      self.slug = candidate
    end
  end

  class_methods do
    attr_accessor :source_attribute, :secondary_slug_attribute

    def slugify(attribute, secondary: nil)
      self.source_attribute = attribute
      self.secondary_slug_attribute = secondary
    end
  end
end
