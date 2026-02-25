# frozen_string_literal: true

require "test_helper"

class WebhookDeliveryTest < ActiveSupport::TestCase
  setup do
    @webhook = webhooks(:test_webhook)
    # Clean up any fixture deliveries so tests have a controlled starting point
    @webhook.webhook_deliveries.destroy_all
  end

  test "belongs_to webhook - invalid without" do
    delivery = WebhookDelivery.new(
      event: "push.viewed",
      payload: {url_token: "abc123"}.to_json,
      response_code: 200,
      success: true
    )

    assert_not delivery.valid?
    assert delivery.errors[:webhook].any?
  end

  test "valid with webhook" do
    delivery = WebhookDelivery.new(
      webhook: @webhook,
      event: "push.viewed",
      payload: {url_token: "abc123"}.to_json,
      response_code: 200,
      response_body: "OK",
      success: true
    )

    assert delivery.valid?
  end

  test "recent scope orders by created_at desc" do
    old_delivery = WebhookDelivery.create!(
      webhook: @webhook,
      event: "push.viewed",
      response_code: 200,
      success: true,
      created_at: 2.days.ago
    )
    new_delivery = WebhookDelivery.create!(
      webhook: @webhook,
      event: "push.expired",
      response_code: 200,
      success: true,
      created_at: 1.hour.ago
    )

    recent = @webhook.webhook_deliveries.recent
    assert_equal new_delivery, recent.first
    assert_equal old_delivery, recent.last
  end

  test "successful scope filters success true" do
    success = WebhookDelivery.create!(
      webhook: @webhook,
      event: "push.viewed",
      response_code: 200,
      success: true
    )
    WebhookDelivery.create!(
      webhook: @webhook,
      event: "push.expired",
      response_code: 500,
      success: false
    )

    successful = @webhook.webhook_deliveries.successful
    assert_includes successful, success
    assert_equal 1, successful.count
  end

  test "failed scope filters success false" do
    WebhookDelivery.create!(
      webhook: @webhook,
      event: "push.viewed",
      response_code: 200,
      success: true
    )
    failure = WebhookDelivery.create!(
      webhook: @webhook,
      event: "push.expired",
      response_code: 500,
      success: false
    )

    failed = @webhook.webhook_deliveries.failed
    assert_includes failed, failure
    assert_equal 1, failed.count
  end
end
