class MemberMailer < ApplicationMailer
  helper :application
  default template_path: 'member_mailer'

  def reset_password_instructions(record, token, opts = {})
    @token = token
    @resource = record
    # TODO : for propper selection of org via slug in the params
    @organisation = record.organisations.first

    I18n.with_locale(@organisation&.default_locale || I18n.default_locale) do
      subject = t('mailers.member_mailer.reset_password_instructions.subject')
      mail(to: record.email, subject: subject, template_path: 'member_mailer')
    end
  end

  def notificate_customer_order
    @order = params[:order]
    @customer = params[:customer]
    org_slug = params[:org_slug]
    @organisation = Organisation.find_by(slug: org_slug)
    mailing_list = @organisation.members.pluck(:email)

    I18n.with_locale(@organisation.default_locale) do
      subject = t('mailers.member_mailer.notificate_customer_order.subject',
                  order_number: @order.order_number,
                  company_name: @customer.company_name)
      mail(to: mailing_list, subject: subject)
    end
  end

  # Invitation email for new team members
  def team_invitation(org_member)
    @org_member = org_member
    @organisation = org_member.organisation
    @inviter = org_member.invited_by
    @invitation_url = accept_invitation_url(
      org_member.invitation_token,
      org_slug: @organisation.slug
    )

    I18n.with_locale(@organisation.default_locale) do
      subject = t('mailers.member_mailer.team_invitation.subject',
                  organisation: @organisation.name)
      mail(to: org_member.invited_email, subject: subject)
    end
  end

  # Notification when existing member is added to an organisation
  def added_to_organisation(org_member)
    @org_member = org_member
    @organisation = org_member.organisation
    @member = org_member.member
    @inviter = org_member.invited_by
    @login_url = new_member_session_url(org_slug: @organisation.slug)

    I18n.with_locale(@organisation.default_locale) do
      subject = t('mailers.member_mailer.added_to_organisation.subject',
                  organisation: @organisation.name)
      mail(to: @member.email, subject: subject)
    end
  end
end
