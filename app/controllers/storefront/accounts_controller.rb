class Storefront::AccountsController < Storefront::BaseController
  skip_after_action :verify_authorized
  before_action :require_customer!

  def show
    build_missing_addresses
  end

  def update
    if password_change?
      update_password
    else
      update_profile
    end
  end

  def toggle_hide_prices
    current_customer_user.update!(hide_prices: !current_customer_user.hide_prices?)
    redirect_back(fallback_location: home_path(org_slug: params[:org_slug]))
  end

  private

  def update_profile
    if current_customer.update(profile_params)
      redirect_to account_path, notice: t("storefront.account.flash.profile_updated")
    else
      build_missing_addresses
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    if current_customer_user.update_with_password(password_params)
      bypass_sign_in(current_customer_user, scope: :customer_user)
      redirect_to account_path, notice: t("storefront.account.flash.password_updated")
    else
      build_missing_addresses
      render :show, status: :unprocessable_entity
    end
  end

  def password_change?
    params[:customer]&.key?(:current_password)
  end

  def profile_params
    params.require(:customer).permit(
      :company_name, :contact_name, :contact_phone, :email, :taxpayer_id, :email_notifications_enabled,
      billing_address_with_archived_attributes: [:id, :street_name, :street_nr, :postal_code, :city, :country, :address_type, :active],
      shipping_addresses_with_archived_attributes: [:id, :street_name, :street_nr, :postal_code, :city, :country, :address_type, :_destroy, :active]
    )
  end

  def password_params
    params.require(:customer).permit(:current_password, :password, :password_confirmation)
  end

  def build_missing_addresses
    @customer = current_customer
    @customer.build_billing_address_with_archived(address_type: "billing") if @customer.billing_address_with_archived.nil?
    @customer.shipping_addresses_with_archived.build(address_type: "shipping") if @customer.shipping_addresses_with_archived.empty?
  end
end
