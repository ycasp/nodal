class Members::InvitationsController < ApplicationController
  layout "auth"
  skip_before_action :authenticate_user!

  before_action :set_org_member, only: [:show, :create]

  def show
    if @org_member.nil?
      redirect_to root_path, alert: "Invalid or expired invitation."
      return
    end

    @member = Member.new(email: @org_member.invited_email)
  end

  def create
    if @org_member.nil?
      redirect_to root_path, alert: "Invalid or expired invitation."
      return
    end

    @member = Member.new(member_params)
    @member.email = @org_member.invited_email  # Ensure email matches invitation

    if @member.save
      @org_member.accept_invitation!(@member)
      sign_in(@member)
      redirect_to bo_path(org_slug: current_organisation.slug), notice: "Welcome to #{current_organisation.name}!"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_org_member
    @org_member = OrgMember.find_by(
      invitation_token: params[:token],
      organisation: current_organisation
    )
  end

  def member_params
    params.require(:member).permit(:first_name, :last_name, :password, :password_confirmation)
  end

  def skip_authorization?
    true
  end

  def skip_pundit_scope?
    true
  end
end
