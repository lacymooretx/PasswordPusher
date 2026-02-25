# frozen_string_literal: true

require "test_helper"

class PushNotificationJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "skips when feature disabled" do
    push = pushes(:test_push)
    push.user.update!(notify_on_view: true)
    audit_log = push.audit_logs.create!(kind: :view, ip: "1.2.3.4", user_agent: "Test", referrer: "")

    assert_no_enqueued_emails do
      PushNotificationJob.perform_now(push.id, "view", audit_log.id)
    end
  end

  test "sends view notification when enabled" do
    Settings.enable_push_notifications = true
    push = pushes(:test_push)
    push.user.update!(notify_on_view: true)
    audit_log = push.audit_logs.create!(kind: :view, ip: "1.2.3.4", user_agent: "Test", referrer: "")

    assert_enqueued_emails 1 do
      PushNotificationJob.perform_now(push.id, "view", audit_log.id)
    end
  ensure
    Settings.enable_push_notifications = false
  end

  test "skips view notification when user opted out" do
    Settings.enable_push_notifications = true
    push = pushes(:test_push)
    push.user.update!(notify_on_view: false)
    audit_log = push.audit_logs.create!(kind: :view, ip: "1.2.3.4", user_agent: "Test", referrer: "")

    assert_no_enqueued_emails do
      PushNotificationJob.perform_now(push.id, "view", audit_log.id)
    end
  ensure
    Settings.enable_push_notifications = false
  end

  test "sends expire notification when enabled" do
    Settings.enable_push_notifications = true
    push = pushes(:test_push)
    push.user.update!(notify_on_expire: true)

    assert_enqueued_emails 1 do
      PushNotificationJob.perform_now(push.id, "expire")
    end
  ensure
    Settings.enable_push_notifications = false
  end
end
