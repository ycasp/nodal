class Storefront::BaseController < ApplicationController
  layout "customer"

  before_action :authenticate_customer!

  private

  def authenticate_customer!
    return if current_customer.present? && current_customer.organisation == current_organisation

    flash[:alert] = "Please sign in to continue."
    redirect_to new_customer_session_path(org_slug: params[:org_slug])
  end
end
