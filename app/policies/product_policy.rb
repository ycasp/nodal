class ProductPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  def export?
    true
  end

  def stock_control?
    !pure_sales_rep?
  end

  def generate_catalog?
    true
  end

  def show?
    belongs_to_organisation?
  end

  def new?
    !pure_sales_rep?
  end

  def create?
    return false if pure_sales_rep?
    # When authorizing class-level actions (like import), record is the class itself
    return true if record == Product

    belongs_to_organisation?
  end

  def import?
    return false unless user.is_a?(Member) && organisation.present?
    return false if pure_sales_rep?

    user.org_members.find_by(organisation: organisation)&.role&.in?(%w[admin owner])
  end

  def add_products?
    import?
  end

  def bulk_create?
    import?
  end

  def bulk_create_process?
    import?
  end

  def bulk_photos?
    import?
  end

  def bulk_photos_process?
    import?
  end

  def edit?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def update?
    edit?
  end

  def destroy?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def delete_photo?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def set_main_photo?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def configure_variants?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def update_variant_configuration?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def related_products?
    !pure_sales_rep? && belongs_to_organisation?
  end

  # The picker's search frame — same page, same permission.
  def related_products_search?
    related_products?
  end

  def update_related_products?
    !pure_sales_rep? && belongs_to_organisation?
  end

  def reorder_related_products?
    !pure_sales_rep? && belongs_to_organisation?
  end

  private

  def belongs_to_organisation?
    return false if user.nil?

    if user.is_a?(Member)
      user.organisations.include?(record.organisation)
    elsif user.is_a?(CustomerUser)
      user.organisation == record.organisation
    else
      false
    end
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      number_of_companies = scope.select("organisation_id").distinct.length
      if number_of_companies <= 1
        scope.all
      else
        # raise an error
      end
    end
  end
end
