class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  before_action :configure_permitted_parameters, if: :devise_controller?
  layout :layout_by_resource
  before_action :current_organisation

  before_action :inject_into_slug

  include Pundit::Authorization

  helper_method :current_organisation

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
    PunditContext.new(current_member || current_customer, current_organisation)
  end

  # accessable form every where, done before everything
  # sets the current organisation
  def current_organisation
    return @current_organisation if defined?(@current_organisation)

    slug = params[:org_slug]
    @current_organisation = Organisation.find_by(slug: slug)
  end

  def authenticate_user!
    return current_member || current_customer
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
    if params[:customer]
      params[:customer][:org_slug] = params[:org_slug]
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
