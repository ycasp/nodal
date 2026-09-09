module ApplicationHelper
  # Returns the OrgMember record for current_member in current_organisation
  def current_org_member
    return nil unless defined?(current_member) && current_member
    return nil unless defined?(current_organisation) && current_organisation

    @current_org_member ||= OrgMember.find_by(
      member: current_member,
      organisation: current_organisation
    )
  end

  # Check if current member has admin or owner role
  def admin_or_owner?
    current_org_member&.role.in?(%w[admin owner])
  end

  # Check if current member is owner
  def owner?
    current_org_member&.role == 'owner'
  end

  # Returns black or white based on background color contrast
  def contrast_color(hex_color)
    return '#000000' if hex_color.blank?

    hex = hex_color.gsub('#', '')
    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    # Calculate relative luminance
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    luminance > 0.5 ? '#000000' : '#ffffff'
  end
end
