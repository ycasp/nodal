class CustomerMailer < ApplicationMailer
  helper :application
  default template_path: 'devise/mailer'

  def invitation_instructions(record, token, opts = {})
    org = Organisation.find(record.organisation_id)
    opts[:org_slug] ||= org.slug # or however you store it
    super
  end

  def reset_password_instructions(record, token, opts = {})
    @token = token
    @resource = record
    mail(to: record.email, subject: "Reset your password",  template_path: 'customer_mailer')
  end
end
