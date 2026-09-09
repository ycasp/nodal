class CustomerAssignment < ApplicationRecord
  belongs_to :org_member
  belongs_to :customer

  validates :customer_id, uniqueness: true
  validates :assigned_at, presence: true

  before_validation :set_assigned_at, on: :create

  private

  def set_assigned_at
    self.assigned_at ||= Time.current
  end
end
