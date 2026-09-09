module BrandingHelper
  def organisation_branding_styles(organisation)
    return '' unless organisation

    primary = organisation.effective_primary_color
    secondary = organisation.effective_secondary_color
    campaign = organisation.effective_campaign_color
    primary_hover = darken_color(primary, 15)
    contrast = contrast_color(primary)
    primary_rgb = hex_to_rgb(primary)
    secondary_rgb = hex_to_rgb(secondary)

    content_tag(:style) do
      <<~CSS.html_safe
        :root {
          --org-primary: #{primary};
          --org-primary-hover: #{primary_hover};
          --org-secondary: #{secondary};
          --org-primary-contrast: #{contrast};
          --org-primary-rgb: #{primary_rgb};
          --org-secondary-rgb: #{secondary_rgb};
          --campaign-color: #{campaign};
        }
      CSS
    end
  end

  # Label for the storefront promotion badge: the org's custom text, or the
  # translated default ("PROMOÇÃO"/"SALE"/"OFERTA") when unset.
  def sale_badge_label(organisation)
    organisation&.sale_badge_text.presence || t('storefront.products.index.sale_badge')
  end

  # Inline style for the promotion badge: the org's colour as background, with a
  # black/white text colour picked for contrast so it stays readable.
  def sale_badge_style(organisation)
    bg = organisation&.effective_sale_badge_color || '#dc3545'
    "background-color: #{bg}; color: #{contrast_color(bg)};"
  end

  def organisation_favicon_tag(organisation)
    return favicon_link_tag("/favicon.svg", type: "image/svg+xml") unless organisation

    if organisation.favicon.attached?
      favicon_link_tag(url_for(organisation.favicon), type: organisation.favicon.content_type)
    else
      # Generate dynamic SVG favicon with org's primary color and first letter
      svg_favicon = generate_favicon_svg(organisation)
      tag.link(rel: "icon", href: "data:image/svg+xml,#{ERB::Util.url_encode(svg_favicon)}", type: "image/svg+xml")
    end
  end

  private

  def generate_favicon_svg(organisation)
    primary_color = organisation.effective_primary_color
    letter = organisation.name.first.upcase
    contrast = contrast_color(primary_color)

    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
        <rect width="32" height="32" rx="6" fill="#{primary_color}"/>
        <text x="16" y="22" font-family="Arial, sans-serif" font-size="18" font-weight="bold" fill="#{contrast}" text-anchor="middle">#{letter}</text>
      </svg>
    SVG
  end

  def darken_color(hex_color, percent)
    hex = hex_color.gsub('#', '')
    rgb = hex.scan(/../).map { |c| c.to_i(16) }
    darkened = rgb.map { |c| [(c * (100 - percent) / 100).round, 0].max }
    '#' + darkened.map { |c| c.to_s(16).rjust(2, '0') }.join
  end

  def contrast_color(hex_color)
    hex = hex_color.gsub('#', '')
    rgb = hex.scan(/../).map { |c| c.to_i(16) }
    luminance = (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255
    luminance > 0.5 ? '#000000' : '#ffffff'
  end

  def hex_to_rgb(hex_color)
    hex = hex_color.gsub('#', '')
    rgb = hex.scan(/../).map { |c| c.to_i(16) }
    rgb.join(', ')
  end
end
