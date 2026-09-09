class Bo::EmailSettingsController < Bo::BaseController
  def edit
    @organisation = current_organisation
    authorize @organisation, policy_class: SettingPolicy
    load_shared_data
  end

  def update
    @organisation = current_organisation
    authorize @organisation, policy_class: SettingPolicy

    ActiveRecord::Base.transaction do
      update_email_settings!
      update_order_notification_recipients!
      update_customer_email_preferences!
    end

    redirect_to edit_bo_email_settings_path(org_slug: @organisation.slug),
                notice: t('bo.email_settings.flash.updated')
  rescue ActiveRecord::RecordInvalid
    load_shared_data
    render :edit, status: :unprocessable_entity
  end

  def email_logs
    @organisation = current_organisation
    authorize @organisation, policy_class: SettingPolicy
    @email_logs = @organisation.email_logs.recent.limit(50)
  end

  private

  def update_email_settings!
    @organisation.update!(email_settings_params)
  end

  def update_order_notification_recipients!
    selected_ids = Array(params[:order_notification_member_ids]).reject(&:blank?).map(&:to_i)

    @organisation.org_members.accepted.where(active: true).find_each do |om|
      om.update_column(:receive_order_notifications, selected_ids.include?(om.id))
    end
  end

  def update_customer_email_preferences!
    opted_out_ids = Array(params[:customer_email_opt_out]).reject(&:blank?).map(&:to_i)

    @organisation.customers.where(active: true).find_each do |customer|
      customer.update_column(:email_notifications_enabled, !opted_out_ids.include?(customer.id))
    end
  end

  def load_shared_data
    @org_members = @organisation.org_members.accepted.where(active: true).includes(:member)
    @customers = @organisation.customers.where(active: true).order(:company_name)
    @recent_email_logs = @organisation.email_logs.recent.limit(50)
  end

  def email_settings_params
    params.require(:organisation).permit(
      :email_sender_name,
      :email_reply_to,
      :email_order_confirmation_enabled,
      :email_discount_notification_enabled
    )
  end
end
