class CustomerMailer < ApplicationMailer
  include OrgEmailDefaults

  helper :application
  layout 'customer_mailer'
  default template_path: 'customer_mailer'

  # Auth-related mails (invitation_instructions, reset_password_instructions)
  # moved to CustomerUserMailer when auth migrated from Customer to CustomerUser.

  def confirm_order
    @customer_user = params[:customer_user]
    @order = params[:order]
    @organisation = @order.organisation
    @customer = @order.customer
    # Optional: the sales rep (Member) who placed the order on behalf of the
    # customer. When present the template renders a "placed by your sales
    # rep" preamble instead of the regular self-service confirmation.
    @placed_by_rep = params[:placed_by_rep]

    unless EmailDeliveryGuard.should_send?(organisation: @organisation, email_type: "order_confirmation", customer: @customer_user)
      log_skipped(@organisation, "order_confirmation", @customer_user.email)
      return
    end

    I18n.with_locale(@organisation.default_locale) do
      subject = if @placed_by_rep
        "Encomenda #{@order.order_number} colocada em seu nome"
      else
        t('mailers.customer_mailer.confirm_order.subject',
          order_number: @order.order_number)
      end
      mail_with_org_defaults(@organisation, to: @customer_user.email, subject: subject)
    end
  end

  def notify_clients_about_discount
    @discount = params[:discount]
    @organisation = params[:organisation]

    unless EmailDeliveryGuard.should_send?(organisation: @organisation, email_type: "discount_notification")
      log_skipped(@organisation, "discount_notification", "bulk")
      return
    end

    mailing_list = @organisation.customers.mailable.pluck(:email)

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
      @organisation.customers.mailable.pluck(:email)
    else
      emails = @promo_code.eligible_customers.mailable.pluck(:email)
      # Also include customers from eligible categories
      if @promo_code.eligible_customer_categories.any?
        category_emails = Customer.mailable.where(
          customer_category_id: @promo_code.eligible_customer_category_ids
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

      mailing_list = @discount.customer_category.customers.mailable.pluck(:email)
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
