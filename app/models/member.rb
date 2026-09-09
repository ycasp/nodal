class Member < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def devise_mailer
    MemberMailer
  end


  has_many :org_members, dependent: :destroy
  has_many :organisations, through: :org_members

  validates :first_name, :last_name, presence: true
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true

  # Devise Invitable's CustomerUser#invite! finishes by calling
  # decrement_invitation_limit! on the inviter (the polymorphic
  # invited_by). Member is not Invitable itself, so this is a no-op
  # that lets the call chain complete cleanly while still recording
  # invited_by for audit purposes. Without this, the invitation IS
  # delivered (DB row + email), but the request 500s on the final step
  # and the BO user sees an error instead of a success flash.
  def decrement_invitation_limit!
    # no-op
  end
end
