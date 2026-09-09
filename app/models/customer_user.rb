class CustomerUser < ApplicationRecord
  # Devise modules — auth lives on CustomerUser (the login), not on
  # Customer (the empresa). One Customer can have many CustomerUsers.
  devise :database_authenticatable,
         :recoverable, :rememberable, :invitable, :trackable,
         authentication_keys: [:email, :organisation_id]

  def devise_mailer
    CustomerUserMailer
  end

  belongs_to :customer
  belongs_to :organisation
  has_many :orders, dependent: :nullify
  has_many :unmet_demands, dependent: :destroy
  has_many :unmet_demand_occurrences, dependent: :destroy
  has_many :quick_access_tokens, dependent: :destroy
  has_many :login_events, class_name: "CustomerUserLoginEvent", dependent: :nullify

  # Each login has its own cart, isolated from other CustomerUsers of the
  # same Customer (empresa). Returns the draft order for this user in the
  # given organisation, creating one if it doesn't exist.
  def current_cart(organisation)
    orders.draft.find_or_create_by!(
      organisation: organisation,
      customer_id: customer_id
    )
  end

  validates :active, inclusion: { in: [true, false] }
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true

  # Mailable: active CustomerUsers whose Customer (empresa) is also active,
  # who have accepted their invitation, and have notifications enabled.
  scope :mailable, -> {
    where(active: true, email_notifications_enabled: true)
      .where.not(invitation_accepted_at: nil)
      .joins(:customer).where(customers: { active: true })
  }

  def mailable?
    active? &&
      email_notifications_enabled? &&
      invitation_accepted_at.present? &&
      customer&.active?
  end

  def invitation_status
    return :inactive unless active?
    return :active if invitation_accepted_at.present?
    return :pending if invitation_sent_at.present?
    :not_invited
  end

  def pending_invitation?
    invitation_status == :pending
  end

  # Devise hook: blocks both new sign-in attempts AND existing sessions.
  # Warden re-checks this on every authenticated request, so deactivating a
  # login (or its empresa) takes effect immediately on whatever browser
  # session that user already had open.
  #
  # A login with no email is a rep-only shell — it exists so an empresa the ERP
  # has no address for can still hold a cart and orders. It has no password
  # either, so Devise would reject it anyway; the explicit check states the
  # intent instead of leaning on that.
  def active_for_authentication?
    super && active? && customer&.active? && email.present?
  end

  def inactive_message
    return :customer_user_inactive unless active?
    return :customer_inactive unless customer&.active?
    super
  end
end
