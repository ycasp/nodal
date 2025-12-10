class Bo::SettingsController < Bo::BaseController
  def edit
    @organisation = current_organisation
    authorize @organisation, policy_class: SettingPolicy
  end

  def update
    @organisation = current_organisation
    authorize @organisation, policy_class: SettingPolicy

    if @organisation.update(organisation_params)
      redirect_to edit_bo_settings_path(org_slug: @organisation.slug), notice: "Settings updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def organisation_params
    params.require(:organisation).permit(:name, :billing_email, :tax_rate, :shipping_cost)
  end
end
