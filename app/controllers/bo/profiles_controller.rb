class Bo::ProfilesController < Bo::BaseController
  def edit
    @member = current_member
    authorize @member, policy_class: ProfilePolicy
  end

  def update
    @member = current_member
    authorize @member, policy_class: ProfilePolicy

    # Remove password fields if they're blank
    filtered_params = profile_params
    if filtered_params[:password].blank?
      filtered_params = filtered_params.except(:password, :password_confirmation)
    end

    if @member.update(filtered_params)
      bypass_sign_in(@member) if profile_params[:password].present?
      redirect_to edit_bo_profile_path(params[:org_slug]), notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:member).permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end
end
