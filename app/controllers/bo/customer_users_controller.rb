class Bo::CustomerUsersController < Bo::BaseController
  before_action :set_customer
  before_action :set_customer_user, only: [:edit, :update, :resend_invitation, :share_invitation, :toggle_active]

  def new
    @customer_user = @customer.customer_users.build
    authorize @customer_user
  end

  def create
    @customer_user = @customer.customer_users.build(customer_user_params)
    @customer_user.organisation = @customer.organisation
    authorize @customer_user

    # Devise Invitable creates the record AND sends the invitation in one
    # call. We set invited_by polymorphically on the attrs hash (instead of
    # passing it as the second arg) because devise_invitable expects the
    # inviter to itself be Invitable, which Member is not — passing it as
    # the second arg would call decrement_invitation_limit! on Member.
    invite_attrs = customer_user_params.to_h.merge(
      customer_id: @customer.id,
      organisation_id: @customer.organisation_id,
      invited_by: current_member
    )
    @customer_user = CustomerUser.invite!(invite_attrs)

    if @customer_user.errors.empty?
      respond_to do |format|
        format.turbo_stream do
          @customer_users = @customer.customer_users.order(:created_at)
          @new_customer_user = @customer.customer_users.build
          flash.now[:notice] = t("bo.customer_users.flash.invited", email: @customer_user.email)
          render :create
        end
        format.html do
          redirect_to bo_customer_path(params[:org_slug], @customer),
                      notice: t("bo.customer_users.flash.invited", email: @customer_user.email)
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @customer_user
  end

  def update
    authorize @customer_user
    if @customer_user.update(customer_user_update_params)
      respond_to do |format|
        format.turbo_stream { head :ok }
        format.json         { head :ok }
        format.html do
          redirect_to bo_customer_path(params[:org_slug], @customer),
                      notice: t("bo.customer_users.flash.updated")
        end
      end
    else
      respond_to do |format|
        format.turbo_stream { render json: { errors: @customer_user.errors }, status: :unprocessable_entity }
        format.json         { render json: { errors: @customer_user.errors }, status: :unprocessable_entity }
        format.html         { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def resend_invitation
    authorize @customer_user
    # Capture status BEFORE invite! so we can pick the right flash key —
    # first send vs. resend.
    was_pending = @customer_user.invitation_status == :pending
    @customer_user.invited_by = current_member
    @customer_user.invite!
    flash_key = was_pending ? "invitation_resent" : "invited"
    redirect_back fallback_location: bo_customer_path(params[:org_slug], @customer),
                  notice: t("bo.customer_users.flash.#{flash_key}", email: @customer_user.email)
  end

  # Generates a fresh invitation token without sending the email, then
  # renders a modal exposing the accept URL plus WhatsApp / SMS / mailto
  # share buttons. This is the deliverability workaround for customers
  # whose corporate Outlook quietly quarantines our invitation emails.
  #
  # IMPORTANT: regenerating invalidates any previous active link the
  # customer may have. Acceptable here because we're explicitly choosing
  # to deliver via another channel.
  def share_invitation
    authorize @customer_user, :resend_invitation?
    @customer_user.invited_by = current_member
    @customer_user.skip_invitation = true
    @customer_user.invite!
    @raw_invitation_token = @customer_user.raw_invitation_token
    @invitation_url = build_invitation_url(@customer_user.organisation, @raw_invitation_token)

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_back fallback_location: bo_customer_path(params[:org_slug], @customer),
                      notice: t("bo.customer_users.flash.share_link_ready",
                                email: @customer_user.email, url: @invitation_url)
      end
    end
  end

  def toggle_active
    authorize @customer_user
    @customer_user.update(active: !@customer_user.active?)
    key = @customer_user.active? ? "activated" : "deactivated"
    redirect_back fallback_location: bo_customer_path(params[:org_slug], @customer),
                  notice: t("bo.customer_users.flash.#{key}", email: @customer_user.email)
  end

  private

  def set_customer
    @customer = current_organisation.customers.find(params[:customer_id])
  end

  def set_customer_user
    @customer_user = @customer.customer_users.find(params[:id])
  end

  # Email is set on creation only — changing it would invalidate Devise
  # auth tokens and any pending invite/reset links.
  def customer_user_params
    params.require(:customer_user).permit(
      :email, :contact_name, :contact_phone, :locale,
      :hide_prices, :email_notifications_enabled
    )
  end

  # Email is editable ONLY while the login is still :not_invited — once the
  # invitation has been delivered, changing the address would leave a stale
  # link in someone's inbox while the real recipient gets nothing. Lock the
  # field server-side regardless of what the form submits.
  def customer_user_update_params
    permitted = [:contact_name, :contact_phone, :locale,
                 :hide_prices, :email_notifications_enabled, :active]
    permitted << :email if @customer_user.invitation_status == :not_invited
    params.require(:customer_user).permit(*permitted)
  end

  # Picks the right route helper based on whether the org has a verified
  # custom_domain. Devise's URL helpers route through main_app, which does
  # not see HostAwareUrlHelpers' dispatcher, so we branch explicitly here.
  def build_invitation_url(organisation, raw_token)
    if organisation.custom_domain_verified?
      custom_host_accept_customer_user_invitation_url(
        invitation_token: raw_token,
        host: organisation.custom_domain,
        protocol: "https"
      )
    else
      accept_customer_user_invitation_url(
        invitation_token: raw_token,
        org_slug: organisation.slug,
        host: Rails.application.config.x.canonical_host,
        protocol: "https"
      )
    end
  end
end
