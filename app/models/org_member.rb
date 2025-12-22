class OrgMember < ApplicationRecord
  belongs_to :organisation
  belongs_to :member, optional: true  # optional for pending invitations
  belongs_to :invited_by, class_name: 'Member', optional: true

  validates :role, presence: true, inclusion: { in: %w[owner admin member] }
  validates :member_id, uniqueness: { scope: :organisation_id, message: "is already a member of this organisation" }, allow_nil: true
  validates :active, inclusion: { in: [true, false] }
  validates :invited_email, presence: true, unless: :member_id?

  before_create :set_defaults

  scope :accepted, -> { where.not(member_id: nil) }
  scope :pending, -> { where(member_id: nil).where.not(invitation_token: nil) }

  # Check if this is a pending invitation
  def pending_invitation?
    member_id.nil? && invitation_token.present?
  end

  # Generate invitation token
  def generate_invitation_token!
    self.invitation_token = SecureRandom.urlsafe_base64(32)
    self.invitation_sent_at = Time.current
    save!
  end

  # Accept invitation and link to member
  def accept_invitation!(member)
    update!(
      member: member,
      invitation_accepted_at: Time.current,
      invitation_token: nil,
      active: true,
      joined_at: Time.current
    )
  end

  # Display name (member name or invited email)
  def display_name
    if member.present?
      "#{member.first_name} #{member.last_name}"
    else
      invited_email
    end
  end

  # Display email
  def display_email
    member&.email || invited_email
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.joined_at ||= Time.current if member_id.present?
  end
end
