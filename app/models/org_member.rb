class OrgMember < ApplicationRecord
  belongs_to :organisation
  belongs_to :member

  validates :role, presence: true, inclusion: { in: %w[owner admin member] }
  validates :member_id, uniqueness: { scope: :organisation_id, message: "is already a member of this organisation" }
  validates :active, inclusion: { in: [true, false] }
end
