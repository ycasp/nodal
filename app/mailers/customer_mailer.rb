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

  def notify_clients_about_discount
    @discount = params[:discount]
    @organisation = params[:organisation]
    mailing_list = @organisation.customers.pluck(:email)
    if @discount.has_attribute?(:product_id) #ProductDiscount
      send_product_discount_mail(mailing_list)
    else #Order Discount
      send_order_discount_mail(mailing_list)
    end
  end

  def notify_customer_about_discount
    @discount = params[:discount]
    @organisation = params[:organisation]
    @customer = @discount.customer
    if @discount.has_attribute?(:product_id) #CustomerProductDiscount
      @product = @discount.product
      subject = "New Discount on #{@product.name}"
      mail(to: @customer.email, subject: subject) do |format|
        format.html { render 'customer_product_discount' }
        format.text { render 'customer_product_discount' }
      end
    else #CustomerDiscount
      subject = "New Discount personal Discount for YOU!"
      mail(to: @customer.email, subject: subject) do |format|
        format.html { render 'customer_discount' }
        format.text { render 'customer_discount' }
      end
    end
  end

  private

  def send_product_discount_mail(mailing_list)
    @product = @discount.product
    subject = "New Product Discount on #{@product.name}"
    mail(to: mailing_list, subject: subject)
  end

  def send_order_discount_mail(mailing_list)
    subject = "New Discount on new Order"
    mail(to: mailing_list, subject: subject)
  end
end
