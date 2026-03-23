module OrgEmailDefaults
  extend ActiveSupport::Concern

  private

  def mail_with_org_defaults(organisation, **options, &block)
    options[:from] ||= organisation.email_from_address
    reply_to = organisation.email_reply_to_address
    options[:reply_to] ||= reply_to if reply_to.present?

    result = block ? mail(**options, &block) : mail(**options)
    log_email(organisation, options, "sent")
    result
  end

  def log_email(organisation, options, status, error_message: nil)
    recipient = Array(options[:to]).first
    EmailLog.create(
      organisation: organisation,
      customer: resolve_customer,
      member: resolve_member,
      email_type: action_name,
      mailer_class: self.class.name,
      recipient_email: recipient.to_s,
      subject: options[:subject],
      status: status,
      error_message: error_message,
      sent_at: Time.current
    )
  rescue => e
    Rails.logger.error("Failed to log email: #{e.message}")
  end

  def log_skipped(organisation, email_type, recipient)
    EmailLog.create(
      organisation: organisation,
      customer: resolve_customer,
      member: resolve_member,
      email_type: email_type,
      mailer_class: self.class.name,
      recipient_email: recipient.to_s,
      subject: nil,
      status: "skipped",
      sent_at: Time.current
    )
  rescue => e
    Rails.logger.error("Failed to log skipped email: #{e.message}")
  end

  def resolve_customer
    customer = instance_variable_get(:@customer)
    return customer if customer.is_a?(Customer)

    resource = instance_variable_get(:@resource)
    resource.is_a?(Customer) ? resource : nil
  end

  def resolve_member
    member = instance_variable_get(:@member)
    return member if member.is_a?(Member)

    resource = instance_variable_get(:@resource)
    resource.is_a?(Member) ? resource : nil
  end
end
