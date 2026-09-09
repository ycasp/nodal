class Storefront::OrderItemsController < Storefront::BaseController
  before_action :require_customer!

  def create
    @product = current_organisation.products.where(published: true).find(params[:product_id])

    if @product.price_on_request?
      redirect_to product_path(org_slug: params[:org_slug], id: @product, **storefront_filter_params), alert: t('storefront.products.show.price_on_request_not_purchasable')
      return
    end

    @order = current_cart

    # Find or default to the product's default variant
    @variant = if params[:variant_id].present?
      @product.product_variants.find(params[:variant_id])
    else
      @product.default_variant
    end

    # Find existing order item by product + variant combination
    @order_item = @order.order_items.find_by(product: @product, product_variant: @variant)

    if @order_item
      @order_item.quantity += order_item_params[:quantity].to_i
    else
      # OrderItem callback set_discount_from_product will use DiscountCalculator
      # to apply the effective discount from all sources (ProductDiscount,
      # CustomerDiscount, CustomerProductDiscount)
      @order_item = @order.order_items.build(
        order_item_params.merge(product: @product, product_variant: @variant)
      )
    end

    authorize @order_item

    # An unlock nudge (and other in-cart actions) can ask to stay on the cart.
    back_path = params[:return_to] == 'cart' ?
      cart_path(org_slug: params[:org_slug]) :
      product_path(org_slug: params[:org_slug], id: @product, **storefront_filter_params)

    if @order_item.save
      redirect_to back_path, notice: t('storefront.cart.item_added')
    else
      redirect_to back_path, alert: @order_item.errors.full_messages.join(", ")
    end
  end

  def update
    @order_item = current_cart.order_items.find(params[:id])
    authorize @order_item

    @order_item.assign_attributes(order_item_params)
    # :customer_change context enforces the minimum-quantity validation for a
    # customer-initiated edit (system re-pricing saves without a context).
    if @order_item.save(context: :customer_change)
      redirect_to cart_path(org_slug: params[:org_slug]), notice: t('storefront.flash.cart_updated')
    else
      redirect_to cart_path(org_slug: params[:org_slug]),
                  alert: @order_item.errors.full_messages.join(", ")
    end
  end

  def destroy
    @order_item = current_cart.order_items.find(params[:id])
    authorize @order_item
    @order_item.destroy
    redirect_to cart_path(org_slug: params[:org_slug]), notice: "Item removed."
  end

  # Bulk add multiple variants of one product to the cart in a single
  # submission. Best-effort: each row saves independently, the response
  # surfaces both successes and per-row failures so the customer isn't
  # blocked by one bad line.
  def bulk_add
    @product = current_organisation.products.where(published: true).find(params[:product_id])
    if @product.price_on_request?
      redirect_to product_path(org_slug: params[:org_slug], id: @product, **storefront_filter_params),
                  alert: t('storefront.products.show.price_on_request_not_purchasable')
      return
    end

    @order = current_cart
    authorize @order.order_items.build(product: @product), :create?
    bulk_items = params[:bulk_items].respond_to?(:each_pair) ? params[:bulk_items] : {}

    added = []
    failed = []

    bulk_items.each_pair do |variant_id, raw_qty|
      qty = raw_qty.to_i
      next if qty <= 0

      variant = @product.product_variants.find_by(id: variant_id)
      label = variant&.option_values_string.presence || variant&.name || variant_id.to_s

      unless variant
        failed << "#{label} (#{t('storefront.cart.bulk_add.variant_not_found')})"
        next
      end

      item = @order.order_items.find_by(product: @product, product_variant: variant)
      if item
        item.quantity += qty
      else
        item = @order.order_items.build(product: @product, product_variant: variant, quantity: qty)
      end

      if item.save
        added << label
      else
        failed << "#{label} (#{item.errors.full_messages.join(', ')})"
      end
    end

    if added.empty? && failed.empty?
      redirect_to product_path(org_slug: params[:org_slug], id: @product, **storefront_filter_params),
                  alert: t('storefront.cart.bulk_add.nothing_selected')
    elsif failed.any?
      flash[:alert] = t('storefront.cart.bulk_add.partial_failure', items: failed.to_sentence)
      redirect_to product_path(org_slug: params[:org_slug], id: @product, **storefront_filter_params),
                  notice: (added.any? ? t('storefront.cart.bulk_add.added', count: added.size) : nil)
    else
      redirect_to product_path(org_slug: params[:org_slug], id: @product, **storefront_filter_params),
                  notice: t('storefront.cart.bulk_add.added', count: added.size)
    end
  end

  # Scan-to-cart: resolve a scanned barcode (a variant SKU, org-unique) and add
  # one unit to the current cart. Repeated scans of the same code increment the
  # line — same find/increment behaviour as #create. Redirects back to the cart
  # so the whole cart re-renders (totals, nudges, discounts) with no duplicated
  # pricing logic. Used by sales reps during impersonation.
  def scan
    code = params[:code].to_s.strip
    if code.blank?
      skip_authorization
      redirect_to(cart_path(org_slug: params[:org_slug])) and return
    end

    @variant = resolve_scanned_variant(code)

    unless @variant
      skip_authorization
      redirect_to cart_path(org_slug: params[:org_slug]),
                  alert: t('storefront.carts.show.scan.not_found', code: code)
      return
    end

    @product = @variant.product

    if @product.price_on_request?
      skip_authorization
      redirect_to cart_path(org_slug: params[:org_slug]),
                  alert: t('storefront.carts.show.scan.not_purchasable', name: @product.name)
      return
    end

    @order = current_cart
    @order_item = @order.order_items.find_by(product: @product, product_variant: @variant)

    if @order_item
      @order_item.quantity += 1
    else
      # First scan seeds the line at the product's minimum (like the product
      # page pre-fills), so a per-variant min_quantity doesn't reject the add.
      # quantity_input_min is 1 for normal/combined-scope products.
      @order_item = @order.order_items.build(
        product: @product, product_variant: @variant, quantity: @product.quantity_input_min
      )
    end

    authorize @order_item, :create?

    if @order_item.save
      label = @variant.option_values_string.presence || @variant.sku
      redirect_to cart_path(org_slug: params[:org_slug]),
                  notice: t('storefront.carts.show.scan.added', name: @product.name, variant: label)
    else
      redirect_to cart_path(org_slug: params[:org_slug]),
                  alert: @order_item.errors.full_messages.join(", ")
    end
  end

  private

  # Resolve a scanned code to a published variant. Exact SKU first (uses the
  # unique index); on a miss, fall back to an alphanumeric-only comparison.
  # Why: barcode scanners on a keyboard layout that differs from the OS emit
  # punctuation wrong — on a Portuguese Mac the "-" key types "'", so a SKU
  # "KBX-CB-003" arrives as "KBX'CB'003". Stripping non-alphanumerics on both
  # sides sidesteps any such substitution. The fallback is accepted only when it
  # resolves to exactly one variant, so an ambiguous strip never adds the wrong
  # item (returns nil → "not found").
  def resolve_scanned_variant(code)
    scope = current_organisation.product_variants
              .joins(:product)
              .where(products: { published: true })

    exact = scope.find_by(sku: code)
    return exact if exact

    normalized = code.gsub(/[^0-9A-Za-z]/, "").upcase
    return nil if normalized.blank?

    matches = scope.where(
      "upper(regexp_replace(product_variants.sku, '[^0-9A-Za-z]', '', 'g')) = ?",
      normalized
    ).limit(2).to_a

    matches.size == 1 ? matches.first : nil
  end

  # Listing context (category, search, page, attribute filters) carried through
  # add/bulk_add so the product page — and its "back to products" link — return
  # the customer to the exact filtered page they came from. attrs is a nested
  # hash, so unwrap it from ActionController::Parameters the way the back link does.
  def storefront_filter_params
    {
      category: params[:category],
      queries: params[:queries],
      page: params[:page],
      promo: params[:promo],
      attrs: params[:attrs].respond_to?(:to_unsafe_h) ? params[:attrs].to_unsafe_h : params[:attrs]
    }.compact
  end

  def order_item_params
    params.require(:order_item).permit(:quantity, :note)
  end
end
