class Bo::SettingsController < Bo::BaseController
  def edit
    @organisation = current_organisation
    authorize @organisation, policy_class: SettingPolicy
    @organisation.build_contact_address(address_type: "contact") unless @organisation.contact_address
    @organisation.build_billing_address(address_type: "billing") unless @organisation.billing_address
  end

  def update
    @organisation = current_organisation
    authorize @organisation, policy_class: SettingPolicy

    if @organisation.update(organisation_params)
      if @organisation.saved_change_to_out_of_stock_strategy?
        RecalculateStockJob.perform_later(@organisation.id)
      end
      redirect_to edit_bo_settings_path(org_slug: @organisation.slug), notice: "Settings updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def organisation_params
    params.require(:organisation).permit(
      :name, :billing_email, :tax_rate, :shipping_mode, :shipping_cost, :free_shipping_threshold, :default_locale, :logo, :primary_color, :secondary_color, :campaign_color,
      :show_sale_badge, :sale_badge_text, :sale_badge_color,
      :contact_email, :phone, :whatsapp, :business_hours, :use_billing_address_for_contact, :show_whatsapp_button,
      :instagram_url, :facebook_url, :linkedin_url, :website_url,
      :storefront_title, :storefront_description, :favicon, :taxpayer_id, :show_related_products, :out_of_stock_strategy, :low_stock_threshold,
      :cart_stock_policy, :cart_qty_overflow_policy, :checkout_stock_policy, :cart_price_change_policy, :max_discount_percentage,
      :show_product_sku, :show_product_sku_on_card, :show_product_min_quantity, :show_product_category, :show_product_availability, :show_scroll_to_top,
      :default_product_sort,
      :terms_and_conditions, :privacy_policy,
      :order_cutoff_time, :lead_time_days, :timezone, :quick_access_token_ttl_days,
      :custom_domain, delivery_day_flags: [],
      contact_address_attributes: [:id, :street_name, :street_nr, :postal_code, :city, :country, :_destroy],
      billing_address_attributes: [:id, :street_name, :street_nr, :postal_code, :city, :country, :_destroy]
    )
  end
end
