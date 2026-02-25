# frozen_string_literal: true

require "test_helper"

class WebhookDeliveryCleanupJobTest < ActiveJob::TestCase
  setup do
    Settings.enable_webhooks = true
    Settings.enable_logins = true
  end

  teardown do
    Settings.reload!
  end

  test "deletes deliveries older than retention period" do
    webhook = webhooks(:test_webhook)

    old_delivery = WebhookDelivery.create!(
      webhook: webhook,
      event: "push.viewed",
      payload: {event: "push.viewed"},
      response_code: 200,
      response_body: "OK",
      success: true,
      created_at: 31.days.ago
    )

    recent_delivery = WebhookDelivery.create!(
      webhook: webhook,
      event: "push.viewed",
      payload: {event: "push.viewed"},
      response_code: 200,
      response_body: "OK",
      success: true,
      created_at: 1.day.ago
    )

    WebhookDeliveryCleanupJob.perform_now

    assert_not WebhookDelivery.exists?(old_delivery.id)
    assert WebhookDelivery.exists?(recent_delivery.id)
  end

  test "skips when webhooks feature is disabled" do
    Settings.enable_webhooks = false

    webhook = webhooks(:test_webhook)
    old_delivery = WebhookDelivery.create!(
      webhook: webhook,
      event: "push.viewed",
      payload: {event: "push.viewed"},
      response_code: 200,
      response_body: "OK",
      success: true,
      created_at: 31.days.ago
    )

    WebhookDeliveryCleanupJob.perform_now

    assert WebhookDelivery.exists?(old_delivery.id)
  end

  test "respects configurable retention period" do
    Settings.webhooks.delivery_retention_days = 7

    webhook = webhooks(:test_webhook)
    delivery = WebhookDelivery.create!(
      webhook: webhook,
      event: "push.viewed",
      payload: {event: "push.viewed"},
      response_code: 200,
      response_body: "OK",
      success: true,
      created_at: 8.days.ago
    )

    WebhookDeliveryCleanupJob.perform_now

    assert_not WebhookDelivery.exists?(delivery.id)
  end
end
