# frozen_string_literal: true

require "test_helper"

class WebhookTest < ActiveSupport::TestCase
  setup do
    @user = users(:giuliana)
  end

  test "valid webhook" do
    webhook = Webhook.new(user: @user, url: "https://example.com/hook", events: ["push.viewed"])
    assert webhook.valid?
  end

  test "requires url" do
    webhook = Webhook.new(user: @user, url: nil, events: ["push.viewed"])
    assert_not webhook.valid?
  end

  test "requires valid url format" do
    webhook = Webhook.new(user: @user, url: "not-a-url", events: ["push.viewed"])
    assert_not webhook.valid?
  end

  test "requires events" do
    webhook = Webhook.new(user: @user, url: "https://example.com/hook", events: [])
    assert_not webhook.valid?
  end

  test "rejects invalid events" do
    webhook = Webhook.new(user: @user, url: "https://example.com/hook", events: ["invalid.event"])
    assert_not webhook.valid?
    assert_includes webhook.errors[:events].join, "invalid"
  end

  test "generates secret on create" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/hook", events: ["push.viewed"])
    assert_not_nil webhook.secret
  end

  test "sign_payload produces HMAC signature" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/hook", events: ["push.viewed"])
    signature = webhook.sign_payload('{"test": true}')
    expected = OpenSSL::HMAC.hexdigest("sha256", webhook.secret, '{"test": true}')
    assert_equal expected, signature
  end

  test "record_success resets failure count" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/hook", events: ["push.viewed"], failure_count: 5)
    webhook.record_success!
    assert_equal 0, webhook.reload.failure_count
    assert_not_nil webhook.last_success_at
  end

  test "record_failure increments count" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/hook", events: ["push.viewed"])
    webhook.record_failure!("HTTP 500")
    assert_equal 1, webhook.reload.failure_count
    assert_equal "HTTP 500", webhook.last_failure_reason
  end

  test "disables after max failures" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/hook", events: ["push.viewed"], failure_count: 9)
    webhook.record_failure!("HTTP 500")
    assert_not webhook.reload.enabled?
  end
end
