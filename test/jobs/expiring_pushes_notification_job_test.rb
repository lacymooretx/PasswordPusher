# frozen_string_literal: true

require "test_helper"

class ExpiringPushesNotificationJobTest < ActiveJob::TestCase
  test "skips when feature disabled" do
    assert_no_enqueued_jobs do
      ExpiringPushesNotificationJob.perform_now
    end
  end

  test "notifies for pushes expiring within 1 day" do
    Settings.enable_push_notifications = true
    push = pushes(:test_push)
    push.user.update!(notify_on_expiring_soon: true)
    push.update_columns(expire_after_days: 1, created_at: Time.current)

    assert_enqueued_with(job: PushNotificationJob) do
      ExpiringPushesNotificationJob.perform_now
    end

    push.reload
    assert_not_nil push.expiring_soon_notified_at
  ensure
    Settings.enable_push_notifications = false
  end

  test "does not double-notify" do
    Settings.enable_push_notifications = true
    push = pushes(:test_push)
    push.user.update!(notify_on_expiring_soon: true)
    push.update_columns(expire_after_days: 1, created_at: Time.current, expiring_soon_notified_at: 1.hour.ago)

    assert_no_enqueued_jobs do
      ExpiringPushesNotificationJob.perform_now
    end
  ensure
    Settings.enable_push_notifications = false
  end
end
