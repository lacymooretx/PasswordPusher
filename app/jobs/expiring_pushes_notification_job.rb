# frozen_string_literal: true

class ExpiringPushesNotificationJob < ApplicationJob
  queue_as :default

  def perform
    return unless Settings.respond_to?(:enable_push_notifications) && Settings.enable_push_notifications

    Push.where(expired: false)
      .where(expiring_soon_notified_at: nil)
      .where.not(user_id: nil)
      .includes(:user)
      .find_each do |push|
        next unless push.days_remaining <= 1
        next unless push.user&.notify_on_expiring_soon?

        PushNotificationJob.perform_later(push.id, "expiring_soon")
        push.update_column(:expiring_soon_notified_at, Time.current)
      end
  end
end
