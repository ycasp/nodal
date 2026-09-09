class QuickAccessToken < ApplicationRecord
  PDF_FORMATS = %i[card digital].freeze

  belongs_to :customer_user
  belongs_to :created_by_member, class_name: "Member", optional: true

  has_one_attached :pdf_card,    dependent: :purge_later
  has_one_attached :pdf_digital, dependent: :purge_later

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  before_validation :generate_token, on: :create
  before_validation :default_expires_at, on: :create

  # Pre-render the 3 PDFs in background as soon as the token is born.
  # Doing this once here means each download is just a redirect to a
  # ready blob — Chrome doesn't get spawned in the request path. Keeps
  # the web dyno calm and the merchant's clicks instant.
  after_create_commit :enqueue_pdf_generation

  # Each CustomerUser has at most one token at a time. Regenerating
  # destroys the previous token (which cascades dependent: :purge_later
  # to its PDF blobs, freeing Cloudinary storage) before creating the
  # new one. We don't keep a "revoked" trail in the tokens table —
  # CustomerUserLoginEvent already records every QR-derived sign-in.
  def self.generate_for(customer_user, created_by:)
    transaction do
      customer_user.quick_access_tokens.find_each(&:destroy!)
      customer_user.quick_access_tokens.create!(created_by_member: created_by)
    end
  end

  def attached_pdf(format)
    public_send("pdf_#{format}")
  end

  def all_pdfs_ready?
    PDF_FORMATS.all? { |fmt| attached_pdf(fmt).attached? }
  end

  def any_pdf_pending?
    !all_pdfs_ready?
  end

  def active?
    revoked_at.nil? && expires_at > Time.current
  end

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  # Revoking destroys the row. We previously kept a `revoked_at` flag
  # so the token survived for audit, but the audit story already lives
  # in CustomerUserLoginEvent and the leftover rows held onto Cloudinary
  # blobs forever (dependent: :purge_later only fires on destroy).
  def revoke!
    destroy!
  end

  def mark_used!
    update_column(:last_used_at, Time.current)
  end

  # When the organisation's TTL is nil, the token is effectively
  # non-expiring. We still store a concrete expires_at (100 years out)
  # so all the existing scopes and queries keep working without a
  # special case. The display layer detects the sentinel via this
  # predicate and shows "Sem expiração" instead of a date.
  def non_expiring?
    expires_at.present? && expires_at > 50.years.from_now
  end

  NON_EXPIRING_HORIZON = 100.years

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def default_expires_at
    return if expires_at.present?

    days = customer_user&.organisation&.quick_access_token_ttl_days
    self.expires_at = days ? days.days.from_now : NON_EXPIRING_HORIZON.from_now
  end

  def enqueue_pdf_generation
    GenerateQuickAccessPdfsJob.perform_later(id)
  end
end
