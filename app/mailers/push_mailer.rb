# frozen_string_literal: true

class PushMailer < ApplicationMailer
  def push_viewed(push, audit_log)
    @push = push
    @audit_log = audit_log
    mail(to: push.user.email, subject: "Your push was viewed")
  end

  def push_expired(push)
    @push = push
    mail(to: push.user.email, subject: "Your push has expired")
  end

  def push_expiring_soon(push)
    @push = push
    mail(to: push.user.email, subject: "Your push is expiring soon")
  end

  # +role+ is :recipient or :supervisor. A supervisor is copied on the same
  # secret link (their view counts against the push's view limit), so the mail
  # says so explicitly rather than reading like a duplicate send.
  def push_dispatched(push, secret_url, recipient_email, role: :recipient)
    @push = push
    @secret_url = secret_url
    @role = role.to_s
    @supervisor = @role == "supervisor"

    from_address = Settings.mail.mailer_sender || "oss@pwpush.com"
    # Extract just the email address if it includes a name
    from_email = from_address[/<(.+)>/, 1] || from_address
    # Prefer the display name configured on mailer_sender, then the brand title.
    # Deliberately NOT push.user.email: on an automation-driven instance the
    # pushing account is a service account (cipp-automation@, n8n-automation@),
    # and putting that in the From, the subject and the body makes a client-facing
    # secret handoff read like a misdirected internal mail.
    configured_from_name = from_address[/\A\s*"?([^"<]+?)"?\s*</, 1]
    sender_label = configured_from_name.presence || Settings.brand.title

    @sender_name = sender_label
    @brand_title = Settings.brand.title

    # Load branding for logo in email
    @branding = if Settings.respond_to?(:enable_user_branding) && Settings.enable_user_branding
      push.team&.team_branding ||
        push.user&.teams&.first&.team_branding ||
        push.user&.user_branding
    end

    # Attach logo as inline image if branding has one
    if @branding&.logo&.attached?
      attachments.inline["logo.png"] = @branding.logo.download
    end

    subject = if @supervisor
      "#{sender_label} shared a secret (you are copied as supervisor)"
    else
      "#{sender_label} has shared a secret with you"
    end

    mail(
      to: recipient_email,
      from: "#{sender_label} <#{from_email}>",
      subject: subject
    )
  end
end
