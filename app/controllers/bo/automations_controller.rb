class Bo::AutomationsController < Bo::BaseController
  before_action :set_automation, only: [ :show, :edit, :update, :destroy, :run_now, :toggle ]

  def index
    authorize Automation
    @automations = policy_scope(Automation).order(:name)
    @last_runs = AutomationRun.where(automation_id: @automations.map(&:id))
                              .select("DISTINCT ON (automation_id) *")
                              .order(:automation_id, created_at: :desc)
                              .index_by(&:automation_id)
  end

  def show
    @runs = @automation.automation_runs.recent.limit(50)
  end

  def new
    @automation = current_organisation.automations.new(
      kind: Automations::Registry.keys.first,
      schedule_kind: "weekly",
      schedule_day: 5,
      schedule_hour: 9,
      schedule_minute: 0
    )
    authorize @automation
    load_form_data
  end

  def create
    @automation = current_organisation.automations.new(automation_params)
    authorize @automation

    if @automation.save
      redirect_to bo_automations_path(params[:org_slug]), notice: t("bo.automations.flash.created")
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_data
  end

  def update
    if @automation.update(automation_params)
      redirect_to bo_automations_path(params[:org_slug]), notice: t("bo.automations.flash.updated")
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @automation.destroy
    redirect_to bo_automations_path(params[:org_slug]), notice: t("bo.automations.flash.deleted")
  end

  # Runs the digest immediately without touching the schedule, so an admin can
  # see what the email looks like without waiting until Friday — and without
  # that test eating the next scheduled digest's period.
  def run_now
    run = Automations::Runner.new(@automation).call(manual: true)

    notice = case run.status
    when AutomationRun::COMPLETED
      t("bo.automations.flash.sent", count: run.rows_count, recipients: run.recipients_count)
    when AutomationRun::SKIPPED
      t("bo.automations.flash.skipped")
    else
      nil
    end

    if notice
      redirect_to bo_automation_path(params[:org_slug], @automation), notice: notice
    else
      redirect_to bo_automation_path(params[:org_slug], @automation),
                  alert: t("bo.automations.flash.failed", error: run.error_message)
    end
  end

  def toggle
    @automation.update(active: !@automation.active)
    # Reactivating recomputes next_run_at (see Automation#schedule_changed?),
    # so a long-disabled automation doesn't fire immediately on the next sweep.
    redirect_to bo_automations_path(params[:org_slug]),
                notice: t(@automation.active? ? "bo.automations.flash.activated" : "bo.automations.flash.deactivated")
  end

  private

  def set_automation
    @automation = policy_scope(Automation).find(params[:id])
    authorize @automation
  end

  def load_form_data
    @report_options = Automations::Registry.options
    @org_members = current_organisation.org_members
                                       .accepted
                                       .where(active: true)
                                       .includes(:member)
                                       .sort_by(&:display_name)
    @suppliers = current_organisation.products
                                     .where.not(supplier: [ nil, "" ])
                                     .distinct
                                     .order(:supplier)
                                     .pluck(:supplier)
    @categories = current_organisation.categories.order(:name)
  end

  def automation_params
    permitted = params.require(:automation).permit(
      :name, :kind, :active, :schedule_kind, :schedule_day, :schedule_time, :skip_if_empty,
      :external_emails_text,
      filters: [ { suppliers: [], category_ids: [] } ],
      recipients: [ { org_member_ids: [] } ]
    )

    external = permitted.delete(:external_emails_text).to_s
                        .split(/[,;\s]+/)
                        .map(&:strip)
                        .reject(&:blank?)

    member_ids = Array(permitted.dig(:recipients, :org_member_ids)).reject(&:blank?)
    permitted[:recipients] = { "org_member_ids" => member_ids, "external_emails" => external }

    filters = permitted[:filters]&.to_h || {}
    filters["suppliers"] = Array(filters["suppliers"]).reject(&:blank?)
    filters["category_ids"] = Array(filters["category_ids"]).reject(&:blank?)
    permitted[:filters] = filters

    permitted
  end
end
