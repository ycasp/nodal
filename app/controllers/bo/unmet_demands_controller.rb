# "Faltas" — the back-office view of demand that customers wanted but couldn't
# take because a cart stock policy cut it (see UnmetDemand / Order#refresh_cart!).
# Grouped empresa → article (per login) → occurrence history. Each article can
# be satisfied (draft order), substituted, or dismissed.
class Bo::UnmetDemandsController < Bo::BaseController
  before_action :set_demand, only: [:satisfy, :substitute, :dismiss]

  def index
    authorize UnmetDemand
    @demands_by_customer = policy_scope(current_organisation.unmet_demands.open)
      .includes(:customer, :customer_user, :product, :product_variant)
      .order(last_seen_at: :desc)
      .group_by(&:customer)
    # For the "Trocar" (substitute) modal — the sellable unit is the variant.
    @substitute_variants = self.class.substitute_variants(current_organisation)
  end

  # Published variants of the org, labelled by product + options + SKU, for the
  # substitute picker. Shared with the customer page block.
  def self.substitute_variants(organisation)
    organisation.product_variants.published
      .includes(:product, attribute_values: :product_attribute)
      .to_a
      # Drop the placeholder base variant of variable products — not a real
      # sellable unit; the actual options are the other variants.
      .reject { |v| v.is_default? && v.product.has_variants? }
      .sort_by { |v| v.display_name.to_s.downcase }
  end

  def satisfy
    authorize @demand
    qty = @demand.shortfall
    @demand.satisfy!(member: current_member)
    redirect_to_customer t("bo.unmet_demands.flash.satisfied", product: @demand.product.name, qty: qty)
  rescue ActiveRecord::RecordInvalid => e
    redirect_back_with_error(e)
  end

  def substitute
    authorize @demand, :satisfy?
    if params[:substitute_variant_id].blank?
      return redirect_to bo_unmet_demands_path(org_slug: current_organisation.slug),
                         alert: t("bo.unmet_demands.substitute_modal.invalid")
    end
    variant = current_organisation.product_variants.find(params[:substitute_variant_id])
    @demand.satisfy!(member: current_member, substitute_variant: variant, quantity: params[:quantity])
    redirect_to_customer t("bo.unmet_demands.flash.substituted",
                           from: @demand.product.name, to: variant.display_name)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_back_with_error(e)
  end

  def dismiss
    authorize @demand
    @demand.dismiss!(member: current_member)
    redirect_to bo_unmet_demands_path(org_slug: current_organisation.slug),
                notice: t("bo.unmet_demands.flash.dismissed", product: @demand.product.name)
  end

  private

  def set_demand
    @demand = current_organisation.unmet_demands.find(params[:id])
  end

  # After satisfy/substitute, land on the customer page (with the "order for
  # this customer" button to finalise) — NOT a misleading placed-order screen.
  def redirect_to_customer(notice)
    redirect_to bo_customer_path(org_slug: current_organisation.slug, id: @demand.customer_id),
                notice: notice
  end

  def redirect_back_with_error(error)
    message = error.respond_to?(:record) && error.record&.errors&.full_messages&.to_sentence.presence
    redirect_to bo_unmet_demands_path(org_slug: current_organisation.slug),
                alert: t("bo.unmet_demands.flash.satisfy_failed", error: message || error.message)
  end
end
