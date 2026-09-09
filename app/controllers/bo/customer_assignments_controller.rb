class Bo::CustomerAssignmentsController < Bo::BaseController
  before_action :set_customer

  # POST /bo/customers/:customer_id/customer_assignment
  # Assigns this customer to a sales rep (or "Nenhum" via param :org_member_id = blank).
  # Admin/owner only — handled by the embedded policy check.
  def create
    authorize @customer, :update?  # reuse customer update gate for owner/admin
    raise Pundit::NotAuthorizedError, "Only admins/owners can assign customers" unless current_org_member&.role&.in?(%w[owner admin])

    rep_id = params[:org_member_id].presence

    if rep_id.blank?
      @customer.customer_assignment&.destroy
      redirect_to bo_customer_path(org_slug: current_organisation.slug, id: @customer.id),
                  notice: "Atribuição de vendedor removida."
      return
    end

    rep = current_organisation.org_members.where(is_sales_rep: true).find(rep_id)

    if @customer.customer_assignment
      @customer.customer_assignment.update!(org_member: rep, assigned_at: Time.current)
    else
      CustomerAssignment.create!(org_member: rep, customer: @customer)
    end

    redirect_to bo_customer_path(org_slug: current_organisation.slug, id: @customer.id),
                notice: "Vendedor atribuído: #{rep.display_name}"
  end

  private

  def set_customer
    @customer = current_organisation.customers.find(params[:customer_id])
  end
end
