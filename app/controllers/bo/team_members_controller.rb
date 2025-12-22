class Bo::TeamMembersController < Bo::BaseController
  before_action :set_org_member, only: [:edit, :update, :destroy, :toggle_active, :resend_invitation]

  def index
    @org_members = policy_scope(current_organisation.org_members).includes(:member)
    authorize OrgMember
  end

  def new
    @org_member = OrgMember.new(organisation: current_organisation)
    authorize @org_member
  end

  def create
    @org_member = OrgMember.new(org_member_params)
    @org_member.organisation = current_organisation
    @org_member.invited_by = current_member
    authorize @org_member

    email = params[:org_member][:invited_email]&.downcase&.strip
    
    # Check if invitation already exists
    invited_member = OrgMember.where(member_id: nil).find_by(invited_email: email, organisation_id: @org_member.organisation_id)
    if invited_member
      flash.now[:alert] = "This Member has already been invited to your organisation!"
      render :new, status: :unprocessable_entity
      return
    end

    # Check if member already exists
    existing_member = Member.find_by(email: email)

    if existing_member

      # Check if already in org
      if current_organisation.members.include?(existing_member)
        flash.now[:alert] = "This email is already a member of this organisation"
        render :new, status: :unprocessable_entity
        return
      end

      # Add existing member to org
      @org_member.member = existing_member

    end
    # New member - set up invitation
    @org_member.invited_email = email
    @org_member.active = true

    if @org_member.save
      if @org_member.member.present?
        # Existing member - send "added to org" notification
        MemberMailer.added_to_organisation(@org_member).deliver_later
        redirect_to bo_team_members_path(params[:org_slug]), notice: "#{existing_member.first_name} has been added to the team."
      else
        # New member - send invitation
        @org_member.generate_invitation_token!
        MemberMailer.team_invitation(@org_member).deliver_later
        redirect_to bo_team_members_path(params[:org_slug]), notice: "Invitation sent to #{email}."
      end
    else

      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @org_member.update(org_member_update_params)
      redirect_to bo_team_members_path(params[:org_slug]), notice: "Team member updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @org_member.display_name
    @org_member.destroy
    redirect_to bo_team_members_path(params[:org_slug]), notice: "#{name} has been removed from the team."
  end

  def toggle_active
    @org_member.update(active: !@org_member.active)
    status = @org_member.active? ? "activated" : "deactivated"
    redirect_to bo_team_members_path(params[:org_slug]), notice: "#{@org_member.display_name} has been #{status}."
  end

  def resend_invitation
    if @org_member.pending_invitation?
      @org_member.generate_invitation_token!
      MemberMailer.team_invitation(@org_member).deliver_later
      redirect_to bo_team_members_path(params[:org_slug]), notice: "Invitation resent to #{@org_member.invited_email}."
    else
      redirect_to bo_team_members_path(params[:org_slug]), alert: "Cannot resend invitation - member has already joined."
    end
  end

  private

  def set_org_member
    @org_member = current_organisation.org_members.find(params[:id])
    authorize @org_member
  end

  def org_member_params
    params.require(:org_member).permit(:role, :invited_email)
  end

  def org_member_update_params
    params.require(:org_member).permit(:role, :active)
  end
end
