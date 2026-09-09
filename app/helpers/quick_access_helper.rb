module QuickAccessHelper
  # Returns a data: URL for the organisation logo so it can be embedded
  # directly into PDF / PNG templates rendered by Grover. Grover runs
  # headless Chrome inside the dyno and would not be able to fetch a
  # localhost / Cloudinary URL reliably from there, so embedding the
  # bytes is the robust path.
  def org_logo_data_url(organisation)
    return nil unless organisation&.logo&.attached?

    blob = organisation.logo.blob
    "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}"
  end

  # Per-CustomerUser state for the QR action in the BO Logins listing.
  #   :unavailable — login is not operational (pending / not invited /
  #                  inactive). QR generation is blocked; show a faded
  #                  icon with tooltip.
  #   :active_token       — has at least one active token. Green icon.
  #   :revoked_or_expired — has tokens, but none active. Warning icon —
  #                         merchant can regenerate.
  #   :no_token           — operational, no token yet. Muted icon.
  def quick_access_state(customer_user)
    return :unavailable unless customer_user.invitation_status == :active

    tokens = customer_user.quick_access_tokens
    return :active_token if tokens.any?(&:active?)
    return :revoked_or_expired if tokens.any?

    :no_token
  end

  # WhatsApp / SMS / mailto deep links for the share buttons. wa.me and
  # sms: both want a digits-only phone (no +, spaces or punctuation),
  # so we normalise here. Returns nil when there isn't enough info to
  # build a usable link, so the view can disable the button cleanly.
  def whatsapp_share_url(phone, text)
    digits = phone.to_s.gsub(/\D/, "")
    return nil if digits.empty?

    "https://wa.me/#{digits}?text=#{CGI.escape(text)}"
  end

  def sms_share_url(phone, text)
    digits = phone.to_s.gsub(/\D/, "")
    return nil if digits.empty?

    "sms:#{digits}?body=#{CGI.escape(text)}"
  end

  def email_share_url(email, subject, body)
    return nil if email.blank?

    "mailto:#{email}?subject=#{CGI.escape(subject)}&body=#{CGI.escape(body)}"
  end
end
