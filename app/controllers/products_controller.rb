class ProductsController < ApplicationController
  #before_action :check_customership
  before_action :check_belongs_to_company

  def index
    @products = policy_scope(current_organisation.products)
  end
end
