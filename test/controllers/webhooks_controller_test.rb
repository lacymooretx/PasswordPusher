# frozen_string_literal: true

require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Settings.enable_webhooks = true
    @user = users(:giuliana)
    sign_in @user
  end

  teardown do
    Settings.enable_webhooks = false
  end

  test "requires authentication" do
    sign_out @user
    get webhooks_path
    assert_response :redirect
  end

  test "redirects when feature disabled" do
    Settings.enable_webhooks = false
    get webhooks_path
    assert_redirected_to root_path
  end

  test "index lists webhooks" do
    get webhooks_path
    assert_response :success
  end

  test "new renders form" do
    get new_webhook_path
    assert_response :success
  end

  test "create webhook" do
    assert_difference("Webhook.count", 1) do
      post webhooks_path, params: {
        webhook: {
          url: "https://example.com/new-hook",
          events: ["push.viewed", "push.expired"]
        }
      }
    end
    assert_redirected_to webhook_path(Webhook.last)
  end

  test "create webhook with invalid URL" do
    assert_no_difference("Webhook.count") do
      post webhooks_path, params: {
        webhook: {
          url: "not-a-url",
          events: ["push.viewed"]
        }
      }
    end
    assert_response :unprocessable_content
  end

  test "show webhook" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/test", events: ["push.viewed"])
    get webhook_path(webhook)
    assert_response :success
  end

  test "edit webhook" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/test", events: ["push.viewed"])
    get edit_webhook_path(webhook)
    assert_response :success
  end

  test "update webhook" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/test", events: ["push.viewed"])
    patch webhook_path(webhook), params: {
      webhook: {url: "https://example.com/updated"}
    }
    assert_redirected_to webhook_path(webhook)
    assert_equal "https://example.com/updated", webhook.reload.url
  end

  test "destroy webhook" do
    webhook = Webhook.create!(user: @user, url: "https://example.com/test", events: ["push.viewed"])
    assert_difference("Webhook.count", -1) do
      delete webhook_path(webhook)
    end
    assert_redirected_to webhooks_path
  end

  test "cannot access other user webhooks" do
    other_user = users(:one)
    webhook = Webhook.create!(user: other_user, url: "https://example.com/test", events: ["push.viewed"])
    get webhook_path(webhook)
    assert_response :not_found
  end
end
