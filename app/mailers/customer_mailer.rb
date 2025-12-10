class CustomerMailer < ApplicationMailer
  helper :application
  default template_path: 'customer_mailer'

  def invitation_instructions(record, token, opts = {})
    org = Organisation.find(record.organisation_id)
    opts[:org_slug] ||= org.slug
    @token = token
    @resource = record
    mail(to: record.email, subject: "Set your password", template_path: 'customer_mailer')
  end

  def reset_password_instructions(record, token, opts = {})
    @token = token
    @resource = record
    mail(to: record.email, subject: "Reset your password",  template_path: 'customer_mailer')
  end

  def confirm_order
    @customer = params[:customer]
    @order = params[:order]
    mail(to: @customer.email, subject: "Orderconfirmation for Order #{@order.order_number}", template_path: 'customer_mailer')
  end
end
