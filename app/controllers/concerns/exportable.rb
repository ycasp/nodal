module Exportable
  extend ActiveSupport::Concern

  def export
    authorize exportable_class, :export?

    task = current_organisation.background_tasks.create!(
      member: current_member,
      task_type: "export_#{exportable_class.model_name.plural}",
      status: :pending
    )

    ExportJob.perform_later(
      task.id,
      organisation_id: current_organisation.id,
      export_class: exportable_class.name,
      export_type: exportable_class.model_name.plural,
      columns: params[:columns],
      format: params[:format_type] || "csv",
      filter_params: filter_params_hash
    )

    redirect_to bo_background_task_path(params[:org_slug], task)
  end
end
