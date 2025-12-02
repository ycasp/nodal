class Bo::DashboardsController < Bo::BaseController
  def dashview
    authorize current_member
  end
end
