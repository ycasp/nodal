class HomepageBanner < ApplicationRecord
  belongs_to :organisation

  has_one_attached :image

  acts_as_list scope: :organisation_id

  TEXT_THEMES = %w[light dark].freeze

  validates :image, presence: true, on: :update
  validates :text_theme, inclusion: { in: TEXT_THEMES }

  scope :active, -> { where(active: true) }
  scope :by_position, -> { order(:position) }
end
