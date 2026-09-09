class ApplicationController < ActionController::Base
  include Pagy::Backend
  include HostAwareUrlHelpers

  before_action :authenticate_user!
  before_action :set_locale

  before_action :configure_permitted_parameters, if: :devise_controller?
  layout :layout_by_resource
  before_action :current_organisation

  before_action :inject_into_slug

  include Pundit::Authorization

  helper_method :current_organisation, :current_customer, :current_org_member,
                :impersonated_customer, :impersonating?

  # Pundit: allow-list approach
  after_action :verify_authorized, unless: :skip_authorization?
  after_action :verify_policy_scoped, unless: :skip_pundit_scope?

  # Uncomment when you *really understand* Pundit!
  # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  # def user_not_authorized
  #   flash[:alert] = "You are not authorized to perform this action."
  #   redirect_to(root_path)
  # end

  private

  def set_locale
    locale = determine_locale
    I18n.locale = locale.to_sym if I18n.available_locales.include?(locale.to_sym)
    cookies[:locale] = { value: I18n.locale.to_s, expires: 1.year.from_now }
  end

  def determine_locale
    # URL parameter takes precedence (for switching)
    return params[:locale] if params[:locale].present?

    # User preference (Member or CustomerUser)
    current_user = current_member || current_customer_user
    return current_user.locale if current_user.respond_to?(:locale) && current_user.locale.present?

    # Organisation default
    return current_organisation.default_locale if current_organisation&.default_locale.present?

    # Cookie fallback
    return cookies[:locale] if cookies[:locale].present?

    # System default
    I18n.default_locale.to_s
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
  end

  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end

  def skip_authorization?
    skip_pundit? || action_name == "index"
  end

  def skip_pundit_scope?
    skip_pundit? || action_name != "index"
  end

  def pundit_user
    PunditContext.new(
      current_member || current_customer_user,
      current_organisation,
      impersonated_customer&.id
    )
  end

  # Compatibility helper: returns the empresa (Customer) for a logged-in
  # CustomerUser, OR the impersonated empresa when a sales rep is acting on
  # someone's behalf. Code that asks for "the company the logged-in user
  # belongs to" should use this; code that needs the login itself should
  # use current_customer_user (provided by Devise).
  def current_customer
    impersonated_customer || current_customer_user&.customer
  end

  # When a sales rep has started an impersonation session, returns the Customer
  # (empresa) they're acting as. Nil otherwise. The session id is sanitised
  # against the current org and the rep's permissions on every read.
  def impersonated_customer
    return @impersonated_customer if defined?(@impersonated_customer)

    @impersonated_customer = resolve_impersonated_customer
  end

  def impersonating?
    impersonated_customer.present?
  end

  def resolve_impersonated_customer
    return nil unless current_member && current_organisation
    id = session[:acting_as_customer_id]
    return nil if id.blank?

    candidate = current_organisation.customers.find_by(id: id)
    return nil unless candidate

    om = current_org_member
    return nil unless om&.is_sales_rep?
    # Owners/admins with the rep flag can impersonate any org customer;
    # pure reps (role: member) only the ones in their carteira.
    return candidate if om.role.in?(%w[owner admin])
    return candidate if om.customer_assignments.exists?(customer_id: candidate.id)

    nil
  end

  # Resolve the tenant for this request. Host wins when an org has the request's
  # host as its custom_domain; otherwise we fall back to the slug embedded in
  # the URL. This keeps the slug URL working unconditionally (source of truth)
  # while letting verified custom domains take precedence transparently.
  def current_organisation
    return @current_organisation if defined?(@current_organisation)

    @current_organisation =
      Organisation.find_by_host(request.host) ||
      Organisation.find_by(slug: params[:org_slug])
  end

  # The OrgMember row binding the logged-in Member to the current organisation.
  # Returns nil for CustomerUser sessions or when the Member isn't a team member here.
  def current_org_member
    return @current_org_member if defined?(@current_org_member)

    @current_org_member =
      if current_member && current_organisation
        current_organisation.org_members.find_by(member_id: current_member.id)
      end
  end

  def authenticate_user!
    return current_member || current_customer_user
  end

  def check_customership
    return if !current_customer.nil? && current_customer.organisation == current_organisation

    flash[:alert]
    redirect_to(root_path)
  end

  def check_belongs_to_company
    return if (!current_customer.nil? && current_customer.organisation == current_organisation) || (!current_member.nil? && current_member.organisations.exists?(current_organisation.id))

    flash[:alert]
    redirect_to(root_path)
  end

  def inject_into_slug
    if params[:customer_user]
      params[:customer_user][:org_slug] = params[:org_slug]
    end
  end

  def layout_by_resource
    if devise_controller?
      "auth"
    else
      "application"
    end
  end
end
