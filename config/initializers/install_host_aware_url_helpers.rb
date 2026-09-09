# Install the URL helper overrides once routes are loaded. Runs at boot so
# the methods are present in every context (tests, console, server, jobs);
# also re-runs on each dev request via to_prepare in case routes reload.
# Re-install on each dev request — when routes change, to_prepare fires and
# we need to refresh the override methods. Boot-time install lives at the
# bottom of config/routes.rb so it runs unconditionally.
Rails.application.config.to_prepare do
  HostAwareUrlHelpers::Dispatcher.install!
end
