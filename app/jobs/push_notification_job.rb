# frozen_string_literal: true

class PushNotificationJob < ApplicationJob
  queue_as :default

  def perform(push_id, event_type, audit_log_id = nil)
    push = Push.find_by(id: push_id)
    return unless push&.user
    return unless Settings.respond_to?(:enable_push_notifications) && Settings.enable_push_notifications

    case event_type.to_s
    when "view"
      return unless push.user.notify_on_view?
      audit_log = AuditLog.find_by(id: audit_log_id)
      return unless audit_log
      PushMailer.push_viewed(push, audit_log).deliver_later
    when "expire"
      return unless push.user.notify_on_expire?
      PushMailer.push_expired(push).deliver_later
    when "expiring_soon"
      return unless push.user.notify_on_expiring_soon?
      PushMailer.push_expiring_soon(push).deliver_later
    end
  end
end
