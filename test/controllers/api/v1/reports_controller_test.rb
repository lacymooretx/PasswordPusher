# frozen_string_literal: true

require "test_helper"

class Api::V1::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_reports = true
    @admin = users(:mr_admin)
    sign_in @admin
  end

  teardown do
    Settings.enable_reports = false
  end

  test "index returns stats JSON" do
    get api_v1_reports_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("overview")
    assert json.key?("period")
    assert json.key?("pushes_by_kind")
    assert json.key?("daily_pushes")
    assert json.key?("security")
    assert json["overview"]["total_users"].is_a?(Integer)
  end

  test "index with custom period" do
    get api_v1_reports_path(format: :json, period: 7)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 7, json["period"]["days"]
  end

  test "non-admin gets forbidden" do
    sign_in users(:one)
    get api_v1_reports_path(format: :json)
    assert_response :forbidden
  end

  test "feature disabled returns not found" do
    Settings.enable_reports = false
    get api_v1_reports_path(format: :json)
    assert_response :not_found
  end
end
