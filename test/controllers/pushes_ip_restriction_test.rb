# frozen_string_literal: true

require "test_helper"

class PushesIpRestrictionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Settings.enable_ip_allowlisting = true
  end

  teardown do
    Settings.enable_ip_allowlisting = false
  end

  test "allows access when no IP restriction" do
    push = pushes(:test_push)
    get push_path(push)
    assert_response :success
  end

  test "blocks access from non-allowed IP" do
    push = pushes(:test_push)
    push.update_column(:allowed_ips, "192.168.1.0/24")
    get push_path(push)
    assert_response :forbidden
  end

  test "feature flag disabled allows all access" do
    Settings.enable_ip_allowlisting = false
    push = pushes(:test_push)
    push.update_column(:allowed_ips, "192.168.1.0/24")
    get push_path(push)
    assert_response :success
  end
end
