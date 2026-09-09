# frozen_string_literal: true

# Context object passed to Pundit policies containing the current user and organisation
PunditContext = Struct.new(:user, :organisation) do
  def id
    user&.id
  end

  def is_a?(klass)
    return true if klass == PunditContext
    user.is_a?(klass)
  end
end
