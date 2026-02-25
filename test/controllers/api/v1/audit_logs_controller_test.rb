# frozen_string_literal: true

require "test_helper"

class Api::V1::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_audit_dashboard = true
    @user = users(:giuliana)
    sign_in @user
  end

  teardown do
    Settings.enable_audit_dashboard = false
  end

  # --- index ---

  test "index returns audit logs for user pushes" do
    get api_v1_audit_logs_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("audit_logs")
    assert json["audit_logs"].is_a?(Array)
    assert json.key?("page")
    assert json.key?("total_pages")
    assert json.key?("total_count")
    # test_push belongs to giuliana and has audit logs
    assert json["audit_logs"].any? { |log| log["push_url_token"] == "testtoken123" }
  end

  test "index filters by kind" do
    get api_v1_audit_logs_path(format: :json), params: {kind: "creation"}
    assert_response :success
    json = JSON.parse(response.body)
    json["audit_logs"].each do |log|
      assert_equal "creation", log["kind"]
    end
  end

  test "index filters by push_token" do
    get api_v1_audit_logs_path(format: :json), params: {push_token: "testtoken123"}
    assert_response :success
    json = JSON.parse(response.body)
    json["audit_logs"].each do |log|
      assert_equal "testtoken123", log["push_url_token"]
    end
  end

  test "index filters by ip" do
    get api_v1_audit_logs_path(format: :json), params: {ip: "127.0.0.1"}
    assert_response :success
    json = JSON.parse(response.body)
    json["audit_logs"].each do |log|
      assert_equal "127.0.0.1", log["ip"]
    end
  end

  test "index returns audit log fields" do
    get api_v1_audit_logs_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    return if json["audit_logs"].empty?

    log = json["audit_logs"].first
    assert log.key?("id")
    assert log.key?("kind")
    assert log.key?("ip")
    assert log.key?("user_agent")
    assert log.key?("referrer")
    assert log.key?("push_url_token")
    assert log.key?("push_kind")
    assert log.key?("created_at")
  end

  # --- feature disabled ---

  test "feature disabled returns not found" do
    Settings.enable_audit_dashboard = false
    get api_v1_audit_logs_path(format: :json)
    assert_response :not_found
  end

  # --- unauthenticated ---

  test "unauthenticated returns unauthorized" do
    sign_out @user
    get api_v1_audit_logs_path(format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end

  # --- token auth ---

  test "token auth works for index" do
    sign_out @user
    get api_v1_audit_logs_path(format: :json),
      headers: {"X-User-Email" => @user.email, "X-User-Token" => @user.authentication_token}
    assert_response :success
  end
end
