# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/push_mailer
class PushMailerPreview < ActionMailer::Preview
  def push_viewed
    push = Push.where.not(user_id: nil).first || Push.first
    audit_log = push.audit_logs.first || AuditLog.new(ip: "127.0.0.1", user_agent: "Preview", kind: :view)
    PushMailer.push_viewed(push, audit_log)
  end

  def push_expired
    push = Push.where.not(user_id: nil).first || Push.first
    PushMailer.push_expired(push)
  end

  def push_expiring_soon
    push = Push.where.not(user_id: nil).first || Push.first
    PushMailer.push_expiring_soon(push)
  end
end
