# frozen_string_literal: true

require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_logins = true
    @admin = users(:mr_admin)
    sign_in @admin
  end

  teardown do
    Settings.enable_logins = false
    SettingOverride.delete_all
  end

  test "admin can access settings index" do
    get admin_settings_path
    assert_response :success
    assert_select "table"
  end

  test "non-admin gets not found" do
    sign_in users(:giuliana)
    get admin_settings_path
    assert_response :not_found
  end

  test "unauthenticated gets not found" do
    sign_out @admin
    get admin_settings_path
    assert_response :not_found
  end

  test "admin can update settings" do
    patch admin_settings_path, params: {settings: {"enable_teams" => "true"}}
    assert_redirected_to admin_settings_path
    assert_equal "Settings updated successfully.", flash[:notice]
  end

  test "update persists to database" do
    patch admin_settings_path, params: {settings: {"enable_teams" => "true"}}
    assert SettingOverride.exists?(key: "enable_teams")
    override = SettingOverride.find_by(key: "enable_teams")
    assert_equal "true", override.value
    assert_equal "boolean", override.value_type
  end

  test "update applies settings in memory" do
    patch admin_settings_path, params: {settings: {"enable_teams" => "true"}}
    assert_equal true, Settings.enable_teams
    Settings.enable_teams = false
  end

  test "update multiple settings at once" do
    patch admin_settings_path, params: {
      settings: {
        "enable_teams" => "true",
        "enable_webhooks" => "true"
      }
    }
    assert_equal 2, SettingOverride.count
    Settings.enable_teams = false
    Settings.enable_webhooks = false
  end
end
