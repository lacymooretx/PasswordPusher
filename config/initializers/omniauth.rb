# frozen_string_literal: true

# OmniAuth SSO Configuration
#
# Google and Microsoft SSO providers are configured here.
# Each provider is only registered if its enabled flag is set to true.
#
# Required environment variables (when enabled):
#   Google:    PWP__SSO__GOOGLE__CLIENT_ID, PWP__SSO__GOOGLE__CLIENT_SECRET
#   Microsoft: PWP__SSO__MICROSOFT__CLIENT_ID, PWP__SSO__MICROSOFT__CLIENT_SECRET
#
# NOTE: Providers must be registered during initialization (not after_initialize)
# so that Devise generates the OmniAuth route helpers before routes are drawn.

Devise.setup do |config|
  if Settings.respond_to?(:sso)
    # Google SSO
    if Settings.sso&.google&.enabled
      client_id = ENV["PWP__SSO__GOOGLE__CLIENT_ID"]
      client_secret = ENV["PWP__SSO__GOOGLE__CLIENT_SECRET"]

      if client_id.present? && client_secret.present?
        config.omniauth :google_oauth2, client_id, client_secret, {
          scope: "email,profile",
          prompt: "select_account"
        }
      else
        Rails.logger.warn "Google SSO is enabled but client_id/client_secret are not set."
      end
    end

    # Microsoft SSO
    # Supports two modes:
    #   1. Single-tenant: PWP__SSO__MICROSOFT__TENANT_ID set → only that tenant can sign in
    #   2. Multi-tenant: PWP__SSO__MICROSOFT__MULTI_TENANT=true → uses "common" endpoint,
    #      validates tenant_id against CspTenant allowlist in the callback controller
    if Settings.sso&.microsoft&.enabled
      client_id = ENV["PWP__SSO__MICROSOFT__CLIENT_ID"]
      client_secret = ENV["PWP__SSO__MICROSOFT__CLIENT_SECRET"]

      tenant_id = ENV["PWP__SSO__MICROSOFT__TENANT_ID"]
      multi_tenant = ENV["PWP__SSO__MICROSOFT__MULTI_TENANT"] == "true"

      if client_id.present? && client_secret.present?
        ms_options = {scope: "openid email profile"}

        if multi_tenant
          # Multi-tenant: use "common" endpoint, validate tenant in callback
          ms_options[:client_options] = {
            authorize_url: "common/oauth2/v2.0/authorize",
            token_url: "common/oauth2/v2.0/token"
          }
        elsif tenant_id.present?
          ms_options[:client_options] = {
            authorize_url: "#{tenant_id}/oauth2/v2.0/authorize",
            token_url: "#{tenant_id}/oauth2/v2.0/token"
          }
        end

        config.omniauth :microsoft_graph, client_id, client_secret, ms_options
      else
        Rails.logger.warn "Microsoft SSO is enabled but client_id/client_secret are not set."
      end
    end
  end
end
