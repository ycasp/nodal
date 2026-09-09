class Bo::ImpersonationsController < Bo::BaseController
  # Authorization is via Pundit on the Customer record (verifies the rep can
  # act on this empresa) rather than a dedicated policy — see authorise_rep_for_customer.

  # POST /bo/impersonations  (params: customer_id)
  # Starts an impersonation session and redirects the rep to the storefront.
  def create
    customer = current_organisation.customers.find(params[:customer_id])
    authorise_rep_for_customer(customer)

    # Cart requires a CustomerUser to hang on (orders.customer_user_id NOT NULL).
    # Seed a stub on demand for customers that never got one — including the
    # ones the ERP has no email for, which is the whole point: the rep sells to
    # them on the road and the empresa gets invited later, keeping the order
    # history on the same login. The helper is idempotent and swallows failures.
    customer.seed_stub_customer_user if customer.customer_users.empty?

    # Safety net: seeding only fails now for genuinely broken data, but never
    # impersonate without a login — the cart insert would blow up downstream.
    if customer.customer_users.empty?
      redirect_to bo_customer_path(org_slug: current_organisation.slug, id: customer.id),
                  alert: "Não é possível impersonar este cliente: não foi possível criar-lhe um login. Cria um login manualmente primeiro."
      return
    end

    session[:acting_as_customer_id] = customer.id

    redirect_to products_path(org_slug: current_organisation.slug),
                notice: "A operar como: #{customer.company_name}"
  end

  # DELETE /bo/impersonations  (no record)
  # Ends the current impersonation session.
  def destroy
    skip_authorization
    session.delete(:acting_as_customer_id)
    redirect_to bo_customers_path(org_slug: current_organisation.slug),
                notice: "Impersonação terminada."
  end

  private

  # Pure reps can impersonate only assigned customers; owners/admins with the
  # rep flag can impersonate any customer in the org (within the scope of
  # what they could normally manage).
  def authorise_rep_for_customer(customer)
    raise Pundit::NotAuthorizedError, "Not a sales rep" unless current_org_member&.is_sales_rep?

    if current_org_member.role == "member"
      assigned_ids = current_org_member.customer_assignments.pluck(:customer_id)
      unless assigned_ids.include?(customer.id)
        raise Pundit::NotAuthorizedError, "Customer not in your carteira"
      end
    end

    # Skip the Pundit verify_authorized check — we did our own gate above.
    skip_authorization
  end
end
