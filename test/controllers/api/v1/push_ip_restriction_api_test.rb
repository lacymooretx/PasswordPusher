# frozen_string_literal: true

require "test_helper"

class Api::V1::PushIpRestrictionApiTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Settings.enable_ip_allowlisting = true
  end

  teardown do
    Settings.reload!
  end

  test "allows access when no IP restriction is set" do
    push = pushes(:test_push)
    get "/p/#{push.url_token}.json"
    assert_response :success
  end

  test "blocks access from non-allowed IP via API" do
    push = pushes(:test_push)
    push.update_column(:allowed_ips, "192.168.1.0/24")

    get "/p/#{push.url_token}.json"
    assert_response :forbidden

    body = JSON.parse(response.body)
    assert_equal "Access denied", body["error"]
  end

  test "allows access from matching IP via API" do
    push = pushes(:test_push)
    # 127.0.0.1 is the default test IP
    push.update_column(:allowed_ips, "127.0.0.1")

    get "/p/#{push.url_token}.json"
    assert_response :success
  end

  test "feature flag disabled allows all access via API" do
    Settings.enable_ip_allowlisting = false
    push = pushes(:test_push)
    push.update_column(:allowed_ips, "192.168.1.0/24")

    get "/p/#{push.url_token}.json"
    assert_response :success
  end

  test "multiple IPs allow matching IP" do
    push = pushes(:test_push)
    push.update_column(:allowed_ips, "10.0.0.0/8, 127.0.0.1")

    get "/p/#{push.url_token}.json"
    assert_response :success
  end
end
