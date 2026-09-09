# Route constraint that matches when request.host belongs to an org's
# custom_domain. Used in config/routes.rb to mount the slugless storefront
# routes on custom hosts, and to redirect BO traffic away from them.
#
# Runs on every request, so we swallow any DB error here — a transient
# database hiccup must not break routing for the (overwhelming majority of)
# canonical-host traffic that doesn't care about custom domains at all.
class CustomDomainConstraint
  def matches?(request)
    Organisation.find_by_host(request.host).present?
  rescue StandardError => e
    Rails.logger.warn("[CustomDomainConstraint] swallowed #{e.class}: #{e.message}")
    false
  end
end
