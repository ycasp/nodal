module Slugable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, on: [:create, :update]

    private

    def source_attribute
      self.class.source_attribute || :name
    end

    def generate_slug
      base_slug = send(source_attribute)&.to_s&.parameterize
      self.slug = base_slug
      # enhace if uniqueness fails (eg. products) - see article of Rui on Slack
    end
  end

  class_methods do
    attr_accessor :source_attribute

    def slugify(attribute)
      self.source_attribute = attribute
    end
  end
end
