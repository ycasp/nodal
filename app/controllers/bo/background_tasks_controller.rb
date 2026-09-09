class Bo::BackgroundTasksController < Bo::BaseController
  def index
    @tasks = policy_scope(BackgroundTask)
      .where(member: current_member)
      .recent
      .limit(20)
  end

  def show
    @task = current_organisation.background_tasks.find(params[:id])
    authorize @task
    @task.update_column(:viewed_at, Time.current) if @task.viewed_at.nil? && @task.status.in?(%w[completed failed cancelled])

    respond_to do |format|
      format.html
      format.json do
        json = {
          status: @task.status,
          progress: @task.progress,
          total: @task.total,
          progress_percentage: @task.progress_percentage,
          result: @task.result,
          error_message: @task.error_message
        }
        json[:download_url] = download_bo_background_task_path(params[:org_slug], @task) if @task.file.attached?
        render json: json
      end
    end
  end

  def cancel
    @task = current_organisation.background_tasks.find(params[:id])
    authorize @task

    # A task that already finished has nothing left to cancel, and writing
    # `cancelled` over it would only lose the outcome it recorded.
    unless @task.pending? || @task.running?
      redirect_to bo_background_tasks_path(params[:org_slug]),
        alert: t("bo.background_tasks.cancel_too_late")
      return
    end

    # Writing the status is the whole mechanism: nothing can kill a running job
    # from the outside, so the job reads this at its next checkpoint and stops
    # itself (see Trackable#checkpoint!).
    @task.update!(status: :cancelled)
    redirect_to bo_background_tasks_path(params[:org_slug]), notice: t("bo.background_tasks.cancelled")
  end

  def download
    @task = current_organisation.background_tasks.find(params[:id])
    authorize @task, :show?

    if @task.file.attached?
      send_data @task.file.download,
        filename: @task.file.filename.to_s,
        content_type: @task.file.content_type,
        disposition: "attachment"
    else
      redirect_to bo_background_task_path(params[:org_slug], @task), alert: t("bo.background_tasks.no_file")
    end
  end
end
