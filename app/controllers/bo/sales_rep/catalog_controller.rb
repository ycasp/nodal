module Bo
  module SalesRep
    # Lets any OrgMember with `is_sales_rep: true` generate a product catalog
    # PDF from their own page, without touching the admin products area.
    #
    # This is a thin wrapper over the exact same machinery the admin catalog
    # uses: it reuses the shared selection modals, GenerateCatalogJob and
    # CatalogPdfService. The only differences are the entry point (this
    # namespace, reachable by pure reps) and that the resulting BackgroundTask
    # is owned by the rep (member: current_member) so they can view/download it.
    class CatalogController < Bo::BaseController
      before_action :ensure_sales_rep
      before_action :skip_pundit

      # Landing page: renders the shared catalog modals wired to this
      # namespace's routes. Product/category selection is loaded lazily via
      # the `selection` action (AJAX turbo-frame), so nothing to preload here.
      def new
      end

      # AJAX endpoint powering the selection turbo-frame. Mirrors
      # Bo::ProductsController#catalog_selection, but renders the shared partial
      # pointed back at this namespace so search/clear stay inside /sales_rep.
      def selection
        @categories = current_organisation.categories.kept.roots.order(:name)

        if params[:query].present?
          scope = current_organisation.products.includes(:categories, :product_variants)
          exact_ids = scope.left_joins(:categories, :product_variants).where(
            "unaccent(products.name) ILIKE unaccent(:q) OR unaccent(products.description) ILIKE unaccent(:q) OR unaccent(products.sku) ILIKE unaccent(:q) OR unaccent(categories.name) ILIKE unaccent(:q) OR unaccent(product_variants.sku) ILIKE unaccent(:q)",
            q: "%#{params[:query]}%"
          ).select("products.id").distinct
          fuzzy_ids = scope.left_joins(:categories).where(
            "word_similarity(unaccent(:q), unaccent(products.name)) > 0.5 OR word_similarity(unaccent(:q), unaccent(categories.name)) > 0.5",
            q: params[:query]
          ).select("products.id").distinct
          scope = scope.where(id: exact_ids).or(scope.where(id: fuzzy_ids)).order(:name)
          @pagy, @products = pagy(scope, items: 30)
          @search_mode = true
        else
          @search_mode = false
        end

        render partial: "bo/products/catalog_selection_content",
               formats: [:html],
               locals: { selection_url: bo_sales_rep_catalog_selection_path(params[:org_slug]) }
      end

      # Enqueues the catalog generation. Same options contract as the admin
      # flow (Bo::ProductsController#generate_catalog) so the shared job/service
      # need no changes. The task is owned by the rep so the download page is
      # reachable for them (see Bo::BaseController guard exception).
      def create
        product_ids = params[:product_ids]&.reject(&:blank?)
        category_ids = params[:catalog_category_ids]&.reject(&:blank?)

        options = {
          "catalog_title" => params[:catalog_title],
          "show_prices" => params[:show_prices],
          "show_sku" => params[:show_sku],
          "show_barcode" => params[:show_barcode],
          "show_description" => params[:show_description],
          "show_variants" => params[:show_variants],
          "show_variant_sku" => params[:show_variant_sku],
          "show_variant_price" => params[:show_variant_price],
          "show_variant_photo" => params[:show_variant_photo],
          "catalog_layout" => params[:catalog_layout],
          "catalog_style" => params[:catalog_style],
          "premium_layout" => params[:premium_layout],
          "orientation" => params[:orientation],
          "catalog_subtitle" => params[:catalog_subtitle],
          "group_by_category" => params[:group_by_category],
          "client_name" => params[:client_name],
          "observations" => params[:observations],
          "only_available" => params[:only_available],
          "only_available_variants" => params[:only_available_variants],
          "sort_by" => params[:sort_by],
          "base_url" => request.base_url
        }

        task = current_organisation.background_tasks.create!(
          member: current_member,
          task_type: "generate_catalog",
          status: :pending
        )

        GenerateCatalogJob.perform_later(
          task.id,
          organisation_id: current_organisation.id,
          product_ids: product_ids,
          category_ids: category_ids,
          options: options
        )

        redirect_to bo_background_task_path(params[:org_slug], task)
      end

      private

      def ensure_sales_rep
        return if current_org_member&.is_sales_rep?

        redirect_to bo_path(org_slug: current_organisation.slug),
                    alert: "Esta página é só para vendedores."
      end

      # This controller does per-action scoping by hand (org-scoped queries +
      # rep guard), like CarteiraController, so opt out of Pundit's after_action
      # verification enforced across the BO.
      def skip_pundit
        skip_authorization
        skip_policy_scope
      end
    end
  end
end
