class LocalesController < ApplicationController
  skip_after_action :verify_authorized, only: [:update]
  skip_after_action :verify_policy_scoped, only: [:update]

  def update
    new_locale = params[:locale]

    if I18n.available_locales.include?(new_locale.to_sym)
      # Update user preference in database
      if current_member
        current_member.update(locale: new_locale)
      elsif current_customer
        current_customer.update(locale: new_locale)
      end

      # Update session
      session[:locale] = new_locale
      cookies[:locale] = { value: new_locale, expires: 1.year.from_now }

      flash[:notice] = "Language updated successfully"
    else
      flash[:alert] = "Invalid language selection"
    end

    redirect_back(fallback_location: root_path)
  end
end
