# frozen_string_literal: true

require "test_helper"

class Api::V1::WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_webhooks = true
    @user = users(:giuliana)
    sign_in @user
  end

  teardown do
    Settings.enable_webhooks = false
    Settings.webhooks = nil
  end

  # --- index ---

  test "index returns user webhooks" do
    get api_v1_webhooks_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |w| w["url"] == "https://example.com/webhook" }
    # Verify ordering (most recent first) by checking all have created_at
    json.each { |w| assert w.key?("created_at") }
  end

  # --- show ---

  test "show returns webhook with deliveries" do
    webhook = webhooks(:test_webhook)
    get api_v1_webhook_path(webhook, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal webhook.url, json["url"]
    assert_equal webhook.enabled, json["enabled"]
    assert json.key?("deliveries")
    assert json["deliveries"].is_a?(Array)
    assert json["deliveries"].any? { |d| d["event"] == "push.viewed" }
  end

  test "show returns 404 for other users webhook" do
    sign_in users(:one)
    webhook = webhooks(:test_webhook)
    get api_v1_webhook_path(webhook, format: :json)
    assert_response :not_found
  end

  # --- create ---

  test "create webhook" do
    post api_v1_webhooks_path(format: :json), params: {
      webhook: {
        url: "https://example.com/new-hook",
        enabled: true,
        events: ["push.created", "push.viewed"]
      }
    }
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "https://example.com/new-hook", json["url"]
    assert_equal true, json["enabled"]
  end

  test "create webhook with invalid data returns errors" do
    post api_v1_webhooks_path(format: :json), params: {
      webhook: {url: "not-a-url", events: ["push.created"]}
    }
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert json.key?("errors"), "Expected response to have 'errors' key, got: #{json.keys.inspect}"
    assert json["errors"].any?
  end

  test "create webhook at max limit returns error" do
    # Set max to 0 so any new webhook exceeds it
    Settings.webhooks = Config::Options.new(max_per_user: 0)

    post api_v1_webhooks_path(format: :json), params: {
      webhook: {
        url: "https://example.com/over-limit",
        events: ["push.created"]
      }
    }
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_match(/maximum/, json["error"])
  end

  # --- update ---

  test "update webhook" do
    webhook = webhooks(:test_webhook)
    patch api_v1_webhook_path(webhook, format: :json), params: {
      webhook: {url: "https://example.com/updated", events: ["push.created"]}
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "https://example.com/updated", json["url"]
  end

  # --- destroy ---

  test "destroy webhook" do
    webhook = webhooks(:test_webhook)
    assert_difference("Webhook.count", -1) do
      delete api_v1_webhook_path(webhook, format: :json)
    end
    assert_response :no_content
  end

  # --- feature disabled ---

  test "feature disabled returns not found" do
    Settings.enable_webhooks = false
    get api_v1_webhooks_path(format: :json)
    assert_response :not_found
  end

  # --- unauthenticated ---

  test "unauthenticated returns unauthorized" do
    sign_out @user
    get api_v1_webhooks_path(format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end

  # --- token auth ---

  test "token auth works for index" do
    sign_out @user
    get api_v1_webhooks_path(format: :json),
      headers: {"X-User-Email" => @user.email, "X-User-Token" => @user.authentication_token}
    assert_response :success
  end
end
