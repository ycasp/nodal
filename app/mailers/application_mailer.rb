class ApplicationMailer < ActionMailer::Base
  include HostAwareUrlHelpers

  default from: -> { "no-reply@#{Rails.application.config.x.canonical_host}" }
  layout "mailer"

  private

  # Mailers have no request, so the in-request predicate from
  # HostAwareUrlHelpers is meaningless here. We derive it from @organisation
  # instead — whoever set @organisation in the action is implicitly choosing
  # which org the email is "for", and that org's preferred_host is the host
  # we want URLs in the body to point at.
  def on_custom_host?
    @organisation.respond_to?(:custom_domain_verified?) && @organisation.custom_domain_verified?
  end

  # Inject the org-specific host into URL generation. Templates calling
  # *_url helpers automatically pick it up.
  def default_url_options
    if @organisation.respond_to?(:preferred_host)
      super.merge(host: @organisation.preferred_host, protocol: "https")
    else
      super
    end
  end
end
