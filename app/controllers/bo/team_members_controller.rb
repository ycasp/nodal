class Bo::TeamMembersController < Bo::BaseController
  before_action :set_org_member, only: [:edit, :update, :destroy, :toggle_active, :resend_invitation, :carteira, :update_carteira]

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
    @editing_self = editing_self?
    @member = @org_member.member if @editing_self
  end

  def update
    @editing_self = editing_self?

    if @editing_self
      @member = @org_member.member
      filtered_params = member_params
      if filtered_params[:password].blank?
        filtered_params = filtered_params.except(:password, :password_confirmation)
      end

      if @member.update(filtered_params)
        bypass_sign_in(@member) if member_params[:password].present?
        redirect_to bo_team_members_path(params[:org_slug]), notice: "Profile updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      if @org_member.update(org_member_update_params)
        redirect_to bo_team_members_path(params[:org_slug]), notice: "Team member updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
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

  # GET /bo/team/:id/carteira — admin/owner two-panel view to bulk add/remove
  # customers to/from a sales rep's carteira.
  def carteira
    raise Pundit::NotAuthorizedError unless current_org_member&.role&.in?(%w[owner admin])
    unless @org_member.is_sales_rep?
      flash[:alert] = "Este membro não é vendedor — ativa primeiro a flag para gerir carteira."
      redirect_to edit_bo_team_member_path(params[:org_slug], @org_member) and return
    end

    skip_authorization

    assigned_ids = @org_member.customer_assignments.pluck(:customer_id)
    org_customers = current_organisation.customers

    @assigned_customers = org_customers.where(id: assigned_ids).order(:company_name)

    @available_query = params[:available_query].to_s.strip
    available_scope = org_customers.where.not(id: assigned_ids).order(:company_name)
    if @available_query.present?
      q = "%#{@available_query}%"
      available_scope = available_scope.where(
        "unaccent(company_name) ILIKE unaccent(:q) OR unaccent(contact_name) ILIKE unaccent(:q) " \
        "OR unaccent(email) ILIKE unaccent(:q) OR unaccent(taxpayer_id) ILIKE unaccent(:q)",
        q: q
      )
    end
    @pagy_available, @available_customers = pagy(available_scope, items: 25, page_param: :available_page)
  end

  # POST /bo/team/:id/update_carteira — bulk add/remove.
  # Params: action_type ("add" | "remove"), customer_ids: []
  def update_carteira
    raise Pundit::NotAuthorizedError unless current_org_member&.role&.in?(%w[owner admin])
    skip_authorization

    action_type = params[:action_type]
    customer_ids = Array(params[:customer_ids]).reject(&:blank?).map(&:to_i)

    if customer_ids.empty? || !%w[add remove].include?(action_type)
      redirect_to carteira_bo_team_member_path(params[:org_slug], @org_member),
                  alert: "Seleciona pelo menos um cliente." and return
    end

    org_customer_ids = current_organisation.customers.where(id: customer_ids).pluck(:id)

    case action_type
    when "add"
      already_assigned = CustomerAssignment.where(customer_id: org_customer_ids).pluck(:customer_id)
      to_add = org_customer_ids - already_assigned
      to_add.each do |cid|
        CustomerAssignment.create!(org_member: @org_member, customer_id: cid)
      end
      notice = "#{to_add.size} cliente(s) adicionado(s) à carteira."
      notice += " (#{(org_customer_ids - to_add).size} já estavam atribuídos a outro vendedor — usa 'remover' lá primeiro)." if to_add.size < org_customer_ids.size
    when "remove"
      removed = CustomerAssignment.where(org_member_id: @org_member.id, customer_id: org_customer_ids).destroy_all
      notice = "#{removed.size} cliente(s) removido(s) da carteira."
    end

    redirect_to carteira_bo_team_member_path(params[:org_slug], @org_member), notice: notice
  end

  private

  def set_org_member
    @org_member = current_organisation.org_members.find(params[:id])
    authorize @org_member
  end

  def org_member_params
    params.require(:org_member).permit(:role, :invited_email, :is_sales_rep)
  end

  def org_member_update_params
    params.require(:org_member).permit(:role, :active, :is_sales_rep)
  end

  def member_params
    params.require(:member).permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end

  def editing_self?
    @org_member.member_id == current_member.id
  end
end
