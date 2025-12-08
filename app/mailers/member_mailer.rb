class MemberMailer < ApplicationMailer
  helper :application
  default template_path: 'devise/mailer'

  def reset_password_instructions(record, token, opts = {})
    @token = token
    @resource = record
    # TODO : for propper selection of org via slug in the params
    @organisation = record.organisations.first
    debugger
    mail(to: record.email, subject: "Reset your password",  template_path: 'member_mailer')
  end
end
