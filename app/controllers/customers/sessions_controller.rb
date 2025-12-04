class Customers::SessionsController < Devise::SessionsController
  before_action :set_organisation
  before_action :configure_sign_in_params, only: :create

  def create
    # 1) find the customer within this org
    customer = @organisation.customers.find_by(email: sign_in_params[:email])

    # 2) check password using Devise helper
    if customer&.valid_password?(sign_in_params[:password])
      # basically what Devise::SessionsController#create does:
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, customer)
      yield customer if block_given?
      respond_with customer, location: after_sign_in_path_for(customer)
    else
      # re-render the form with error like Devise would
      self.resource = resource_class.new(sign_in_params)
      set_flash_message!(:alert, :invalid)
      respond_with_navigational(resource) { render :new, status: :unprocessable_entity }
    end
  end

  private

  # Use the slug from the scope: /:org_slug/customers/sign_in
  def set_organisation
    @organisation = Organisation.find_by!(slug: params[:org_slug])
  end

  # Inject organization_id so Devise authenticates on [email, organization_id]
  def configure_sign_in_params
    # Make sure the param exists
    params[:customer] ||= {}

    params[:customer][:organisation_id] = @organisation.id

    # Tell Devise it's allowed to read this key
    devise_parameter_sanitizer.permit(:sign_in, keys: [:organisation_id])
  end
end
