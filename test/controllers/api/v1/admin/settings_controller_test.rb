# frozen_string_literal: true

require "test_helper"

class Api::V1::Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:mr_admin)
    sign_in @admin
  end

  teardown do
    SettingOverride.delete_all
  end

  test "index returns settings" do
    get api_v1_admin_settings_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("settings")
    assert json["settings"].is_a?(Array)
    assert json["settings"].any? { |s| s["key"] == "enable_logins" }
  end

  test "index includes value and type info" do
    get api_v1_admin_settings_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    setting = json["settings"].find { |s| s["key"] == "enable_logins" }
    assert setting.key?("value")
    assert setting.key?("default")
    assert setting.key?("overridden")
    assert setting.key?("value_type")
  end

  test "update persists setting" do
    patch api_v1_admin_settings_path(format: :json), params: {
      settings: {"enable_logins" => true}
    }
    assert_response :success
    assert SettingOverride.exists?(key: "enable_logins")
  end

  test "update returns success message" do
    patch api_v1_admin_settings_path(format: :json), params: {
      settings: {"enable_logins" => true}
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Settings updated successfully", json["message"]
    assert json["updated"].include?("enable_logins")
  end

  test "bulk update multiple settings" do
    patch api_v1_admin_settings_path(format: :json), params: {
      settings: {
        "enable_logins" => true,
        "enable_teams" => true,
        "webhooks.max_per_user" => 25
      }
    }
    assert_response :success
    assert_equal 3, SettingOverride.count
  end

  test "update overwrites existing override" do
    SettingOverride.create!(key: "enable_logins", value: "false", value_type: "boolean")
    patch api_v1_admin_settings_path(format: :json), params: {
      settings: {"enable_logins" => true}
    }
    assert_response :success
    assert_equal "true", SettingOverride.find_by(key: "enable_logins").value
  end

  test "non-admin gets forbidden" do
    sign_in users(:giuliana)
    get api_v1_admin_settings_path(format: :json)
    assert_response :forbidden
  end

  test "unauthenticated gets unauthorized" do
    sign_out @admin
    get api_v1_admin_settings_path(format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end
end
