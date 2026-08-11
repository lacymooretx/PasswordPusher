# frozen_string_literal: true

# Register the SMTP2GO HTTP API as an ActionMailer delivery method.
#
# Runs inside to_prepare so the autoloaded MailDelivery::Smtp2goApi constant is
# resolved through Zeitwerk (referencing it directly from an initializer body
# would pin a stale class across reloads). Registration happens before any mail
# is built, which is all ActionMailer requires -- delivery_method is looked up
# by symbol at message-build time.
Rails.application.config.to_prepare do
  ActionMailer::Base.add_delivery_method(:smtp2go_api, MailDelivery::Smtp2goApi)
end
