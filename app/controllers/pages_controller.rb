class PagesController < ApplicationController
  skip_before_action :authenticate_member!, only: :home

  def home
  end

  def  index
  end

end
