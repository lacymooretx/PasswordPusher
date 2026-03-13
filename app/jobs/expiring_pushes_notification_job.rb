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
        threshold = if Settings.respond_to?(:push_notifications) && Settings.push_notifications.respond_to?(:expiring_soon_days)
          Settings.push_notifications.expiring_soon_days
        else
          1
        end
        next unless push.days_remaining <= threshold
        next unless push.user&.notify_on_expiring_soon?

        PushNotificationJob.perform_later(push.id, "expiring_soon")
        push.update_column(:expiring_soon_notified_at, Time.current)
      end
  end
end
