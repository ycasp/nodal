class CustomerMailer < ApplicationMailer
  include OrgEmailDefaults

  helper :application
  layout 'customer_mailer'
  default template_path: 'customer_mailer'

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

  def confirm_order
    @customer = params[:customer]
    @order = params[:order]
    @organisation = @order.organisation

    unless EmailDeliveryGuard.should_send?(organisation: @organisation, email_type: "order_confirmation", customer: @customer)
      log_skipped(@organisation, "order_confirmation", @customer.email)
      return
    end

    I18n.with_locale(@organisation.default_locale) do
      subject = t('mailers.customer_mailer.confirm_order.subject',
                  order_number: @order.order_number)
      mail_with_org_defaults(@organisation, to: @customer.email, subject: subject)
    end
  end

  def notify_clients_about_discount
    @discount = params[:discount]
    @organisation = params[:organisation]

    unless EmailDeliveryGuard.should_send?(organisation: @organisation, email_type: "discount_notification")
      log_skipped(@organisation, "discount_notification", "bulk")
      return
    end

    mailing_list = @organisation.customers.where(email_notifications_enabled: true).pluck(:email)

    I18n.with_locale(@organisation.default_locale) do
      if @discount.has_attribute?(:product_id) # ProductDiscount
        send_product_discount_mail(mailing_list)
      else # Order Discount
        send_order_discount_mail(mailing_list)
      end
    end
  end

  def notify_promo_code
    @promo_code = params[:promo_code]
    @organisation = params[:organisation]

    unless EmailDeliveryGuard.should_send?(organisation: @organisation, email_type: "discount_notification")
      log_skipped(@organisation, "discount_notification", "bulk")
      return
    end

    mailing_list = if @promo_code.eligibility == "all_customers"
      @organisation.customers.where(email_notifications_enabled: true).pluck(:email)
    else
      emails = @promo_code.eligible_customers.where(email_notifications_enabled: true).pluck(:email)
      # Also include customers from eligible categories
      if @promo_code.eligible_customer_categories.any?
        category_emails = Customer.where(
          customer_category_id: @promo_code.eligible_customer_category_ids,
          email_notifications_enabled: true
        ).pluck(:email)
        emails = (emails + category_emails).uniq
      end
      emails
    end

    return if mailing_list.empty?

    I18n.with_locale(@organisation.default_locale) do
      subject = t('mailers.customer_mailer.promo_code.subject', code: @promo_code.code)
      mail_with_org_defaults(@organisation, bcc: mailing_list, subject: subject)
    end
  end

  def notify_customer_about_discount
    @discount = params[:discount]
    @organisation = params[:organisation]

    if @discount.category_based?
      unless EmailDeliveryGuard.should_send?(organisation: @organisation, email_type: "discount_notification")
        log_skipped(@organisation, "discount_notification", "bulk")
        return
      end

      mailing_list = @discount.customer_category.customers
        .where(active: true, email_notifications_enabled: true)
        .pluck(:email)
      return if mailing_list.empty?

      # Templates reference @customer.contact_name — use nil for BCC emails (templates handle it)
      @customer = OpenStruct.new(contact_name: nil)

      I18n.with_locale(@organisation.default_locale) do
        if @discount.has_attribute?(:product_id) # CustomerProductDiscount
          @product = @discount.product
          @category = @discount.category
          subject_name = @product&.name || @category&.name
          subject = t('mailers.customer_mailer.customer_product_discount.subject',
                      product_name: subject_name)
          mail_with_org_defaults(@organisation, bcc: mailing_list, subject: subject) do |format|
            format.html { render 'customer_product_discount' }
            format.text { render 'customer_product_discount' }
          end
        else # CustomerDiscount
          subject = t('mailers.customer_mailer.customer_discount.subject')
          mail_with_org_defaults(@organisation, bcc: mailing_list, subject: subject) do |format|
            format.html { render 'customer_discount' }
            format.text { render 'customer_discount' }
          end
        end
      end
    else
      @customer = @discount.customer

      unless EmailDeliveryGuard.should_send?(organisation: @organisation, email_type: "discount_notification", customer: @customer)
        log_skipped(@organisation, "discount_notification", @customer.email)
        return
      end

      I18n.with_locale(@organisation.default_locale) do
        if @discount.has_attribute?(:product_id) # CustomerProductDiscount
          @product = @discount.product
          @category = @discount.category
          subject_name = @product&.name || @category&.name
          subject = t('mailers.customer_mailer.customer_product_discount.subject',
                      product_name: subject_name)
          mail_with_org_defaults(@organisation, to: @customer.email, subject: subject) do |format|
            format.html { render 'customer_product_discount' }
            format.text { render 'customer_product_discount' }
          end
        else # CustomerDiscount
          subject = t('mailers.customer_mailer.customer_discount.subject')
          mail_with_org_defaults(@organisation, to: @customer.email, subject: subject) do |format|
            format.html { render 'customer_discount' }
            format.text { render 'customer_discount' }
          end
        end
      end
    end
  end

  private

  def send_product_discount_mail(mailing_list)
    @product = @discount.product
    @category = @discount.category
    subject_name = @product&.name || @category&.name
    if @product
      subject = t('mailers.customer_mailer.product_discount.subject',
                  product_name: subject_name)
    else
      subject = t('mailers.customer_mailer.product_discount.category_subject',
                  category_name: subject_name)
    end
    mail_with_org_defaults(@organisation, bcc: mailing_list, subject: subject)
  end

  def send_order_discount_mail(mailing_list)
    subject = t('mailers.customer_mailer.order_discount.subject')
    mail_with_org_defaults(@organisation, bcc: mailing_list, subject: subject)
  end
end
