# frozen_string_literal: true

require "test_helper"

class Api::V1::NotificationPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_push_notifications = true
    @user = users(:giuliana)
    sign_in @user
  end

  teardown do
    Settings.enable_push_notifications = false
  end

  test "show returns current preferences" do
    get api_v1_account_notifications_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("notify_on_view")
    assert json.key?("notify_on_expire")
    assert json.key?("notify_on_expiring_soon")
  end

  test "update changes preferences" do
    patch api_v1_account_notifications_path(format: :json), params: {
      notify_on_view: true,
      notify_on_expire: true,
      notify_on_expiring_soon: false
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["notify_on_view"]
    assert_equal true, json["notify_on_expire"]
    assert_equal false, json["notify_on_expiring_soon"]
  end

  test "feature disabled returns not found" do
    Settings.enable_push_notifications = false
    get api_v1_account_notifications_path(format: :json)
    assert_response :not_found
  end

  test "unauthenticated returns unauthorized" do
    sign_out @user
    get api_v1_account_notifications_path(format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end

  test "token auth works" do
    sign_out @user
    get api_v1_account_notifications_path(format: :json),
      headers: {"X-User-Email" => @user.email, "X-User-Token" => @user.authentication_token}
    assert_response :success
  end
end
