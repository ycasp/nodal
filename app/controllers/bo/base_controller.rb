class Bo::BaseController < ApplicationController
  layout "bo"
  before_action :check_membership
  before_action :set_sidebar_counts

  private

  # done before every bo/ route - checks if member is part of current org
  # redirets to root if not
  def check_membership
    return if !current_member.nil? && current_member.organisations.exists?(current_organisation.id)
    flash[:alert]
    redirect_to(root_path)
  end

  def set_sidebar_counts
    @unreviewed_orders_count = current_organisation.orders.unreviewed.count
  end
end
