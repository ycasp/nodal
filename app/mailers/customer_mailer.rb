class CustomerMailer < ApplicationMailer
  helper :application
  default template_path: 'devise/mailer'

  def invitation_instructions(record, token, opts = {})
    org = Organisation.find(record.organisation_id)
    opts[:org_slug] ||= org.slug # or however you store it
    super
  end
end
