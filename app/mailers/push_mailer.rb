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

  def push_dispatched(push, secret_url, recipient_email)
    @push = push
    @secret_url = secret_url
    @sender_name = push.user&.email || Settings.brand.title
    @brand_title = Settings.brand.title

    from_name = if push.user&.email.present?
      "#{push.user.email} via #{Settings.brand.title}"
    else
      Settings.brand.title
    end

    from_address = Settings.mail.mailer_sender || "oss@pwpush.com"
    # Extract just the email address if it includes a name
    from_email = from_address[/<(.+)>/, 1] || from_address

    mail(
      to: recipient_email,
      from: "#{from_name} <#{from_email}>",
      subject: "#{push.user&.email || Settings.brand.title} has shared a secret with you"
    )
  end
end
