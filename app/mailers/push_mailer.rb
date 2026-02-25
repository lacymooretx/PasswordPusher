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
end
