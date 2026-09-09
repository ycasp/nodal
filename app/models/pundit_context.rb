# frozen_string_literal: true

# Context object passed to Pundit policies containing the current user, the
# current organisation, and (optionally) the id of an empresa being
# impersonated by a sales rep — policies that gate cart/order actions need
# to know whether the Member is acting as the customer for this empresa.
PunditContext = Struct.new(:user, :organisation, :impersonated_customer_id) do
  def id
    user&.id
  end

  def is_a?(klass)
    return true if klass == PunditContext
    user.is_a?(klass)
  end

  def impersonating?
    impersonated_customer_id.present?
  end
end
