# frozen_string_literal: true

require "test_helper"

class AuditDashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @giuliana = users(:giuliana)
    @one = users(:one)
    @test_push = pushes(:test_push)
  end

  test "index requires authentication" do
    get audit_dashboard_index_path
    assert_response :redirect
  end

  test "index requires feature flag" do
    sign_in @one
    get audit_dashboard_index_path
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "index shows audit logs when enabled" do
    Settings.enable_audit_dashboard = true
    sign_in @giuliana
    get audit_dashboard_index_path
    assert_response :success
  ensure
    Settings.enable_audit_dashboard = false
  end

  test "index filters by kind" do
    Settings.enable_audit_dashboard = true
    sign_in @giuliana
    get audit_dashboard_index_path, params: {kind: "view"}
    assert_response :success
  ensure
    Settings.enable_audit_dashboard = false
  end

  test "index filters by push_token" do
    Settings.enable_audit_dashboard = true
    sign_in @giuliana
    get audit_dashboard_index_path, params: {push_token: "testtoken123"}
    assert_response :success
  ensure
    Settings.enable_audit_dashboard = false
  end
end
