# frozen_string_literal: true

class ClientMailer < ApplicationMailer
  def onboarding_email(csp_tenant, recipient_email)
    @tenant = csp_tenant
    @app_url = Settings.override_base_url || "https://pwpush.com"
    @brand_title = Settings.brand.title

    # Load branding for logo
    @branding = TeamBranding.joins(:team).where(teams: {}).first if defined?(TeamBranding)
    @branding ||= begin
      Team.first&.team_branding
    rescue
      nil
    end

    if @branding&.logo&.attached?
      attachments.inline["logo.png"] = @branding.logo.download
    end

    mail(
      to: recipient_email,
      subject: "Welcome to #{@brand_title} — Secure Secret Sharing for #{@tenant.name}"
    )
  end
end
