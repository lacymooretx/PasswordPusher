# frozen_string_literal: true

require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_reports = true
    Settings.enable_logins = true
    @admin = users(:mr_admin)
    sign_in @admin
  end

  teardown do
    Settings.enable_reports = false
  end

  test "index shows dashboard" do
    get reports_path
    assert_response :success
    assert_match "Usage", response.body
  end

  test "index with period param" do
    get reports_path(period: "7")
    assert_response :success
  end

  test "non-admin gets redirected" do
    sign_in users(:one)
    get reports_path
    assert_redirected_to root_path
  end

  test "feature disabled redirects" do
    Settings.enable_reports = false
    get reports_path
    assert_redirected_to root_path
  end

  test "requires authentication" do
    sign_out @admin
    get reports_path
    assert_redirected_to new_user_session_path
  end
end
