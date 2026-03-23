class Storefront::PromoCodesController < Storefront::BaseController
  skip_after_action :verify_authorized
  before_action :require_customer!

  def apply
    order = current_cart
    code = params[:code]&.upcase&.strip

    if code.blank?
      redirect_to checkout_path(org_slug: params[:org_slug]),
                  alert: t('storefront.promo_codes.errors.blank')
      return
    end

    promo_code = current_organisation.promo_codes.find_by(code: code)

    if promo_code.nil?
      redirect_to checkout_path(org_slug: params[:org_slug]),
                  alert: t('storefront.promo_codes.errors.not_found')
      return
    end

    result = promo_code.redeemable_by?(current_customer, order)

    if result == :ok
      order.update!(promo_code: promo_code)
      redirect_to checkout_path(org_slug: params[:org_slug]),
                  notice: t('storefront.promo_codes.applied', code: promo_code.code, discount: promo_code.value_display)
    else
      error_message = case result
      when :inactive then t('storefront.promo_codes.errors.inactive')
      when :expired then t('storefront.promo_codes.errors.expired')
      when :usage_limit_reached then t('storefront.promo_codes.errors.usage_limit')
      when :customer_limit_reached then t('storefront.promo_codes.errors.customer_limit')
      when :not_eligible then t('storefront.promo_codes.errors.not_eligible')
      when :min_amount_not_met then t('storefront.promo_codes.errors.min_amount', amount: promo_code.min_order_amount.format)
      else t('storefront.promo_codes.errors.invalid')
      end

      redirect_to checkout_path(org_slug: params[:org_slug]), alert: error_message
    end
  end

  def remove
    order = current_cart
    order.update!(promo_code: nil, promo_code_discount_amount_cents: 0)
    redirect_to checkout_path(org_slug: params[:org_slug]),
                notice: t('storefront.promo_codes.removed')
  end
end
