class Customers::PasswordsController < Devise::PasswordsController
  before_action :set_organisation

  private

  def set_organisation
    @organisation = Organisation.find_by!(slug: params[:org_slug])
  end
end
