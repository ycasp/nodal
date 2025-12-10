class MemberMailer < ApplicationMailer
  helper :application
  default template_path: 'member_mailer'

  def reset_password_instructions(record, token, opts = {})
    @token = token
    @resource = record
    # TODO : for propper selection of org via slug in the params
    @organisation = record.organisations.first
    mail(to: record.email, subject: "Reset your password",  template_path: 'member_mailer')
  end

  def notificate_customer_order
    @order = params[:order]
    @customer = params[:customer]
    org_slug = params[:org_slug]
    @organisation = Organisation.find_by(slug: org_slug)
    mailing_list = @organisation.members.pluck(:email)
    subject = "New order #{@order.order_number} from #{@customer.company_name}"
    mail(to: mailing_list, subject: subject)
  end
end
