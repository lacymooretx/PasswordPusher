# frozen_string_literal: true

# Operational alerts for administrators. Not user-facing mail.
class AdminMailer < ApplicationMailer
  # Sent when ClamAV cannot be reached. While this is true, file pushes are
  # accepted and served without ever being scanned.
  def clamav_unavailable(to, target:, down_since:, downtime:)
    @target = target
    @down_since = down_since
    @downtime = downtime
    @site = Settings.brand.respond_to?(:title) ? Settings.brand.title : "Password Pusher"

    mail(
      to: to,
      subject: "[#{@site}] ClamAV is unreachable — file pushes are not being scanned"
    )
  end

  # Sent once, after a previously alerted outage clears.
  def clamav_recovered(to, target:, down_since:, downtime:)
    @target = target
    @down_since = down_since
    @downtime = downtime
    @site = Settings.brand.respond_to?(:title) ? Settings.brand.title : "Password Pusher"

    mail(
      to: to,
      subject: "[#{@site}] ClamAV has recovered"
    )
  end
end
