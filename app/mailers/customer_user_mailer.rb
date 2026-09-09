class CustomerUserMailer < ApplicationMailer
  include OrgEmailDefaults

  helper :application
  layout 'customer_mailer'
  default template_path: 'customer_user_mailer'

  def invitation_instructions(record, token, opts = {})
    @organisation = record.organisation
    opts[:org_slug] ||= @organisation.slug
    @token = token
    @resource = record

    I18n.with_locale(@organisation.default_locale) do
      subject = t('mailers.customer_mailer.invitation_instructions.subject')
      mail_with_org_defaults(@organisation, to: record.email, subject: subject)
    end
  end

  def reset_password_instructions(record, token, opts = {})
    @organisation = record.organisation
    @token = token
    @resource = record

    I18n.with_locale(@organisation.default_locale) do
      subject = t('mailers.customer_mailer.reset_password_instructions.subject')
      mail_with_org_defaults(@organisation, to: record.email, subject: subject)
    end
  end
end
