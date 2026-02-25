# frozen_string_literal: true

require "test_helper"

class PushIpRestrictionTest < ActiveSupport::TestCase
  test "ip_allowed? returns true when no restrictions" do
    push = pushes(:test_push)
    assert push.ip_allowed?("1.2.3.4")
  end

  test "ip_allowed? matches exact IP" do
    push = pushes(:test_push)
    push.allowed_ips = "1.2.3.4, 5.6.7.8"
    assert push.ip_allowed?("1.2.3.4")
    assert push.ip_allowed?("5.6.7.8")
    assert_not push.ip_allowed?("9.9.9.9")
  end

  test "ip_allowed? matches CIDR range" do
    push = pushes(:test_push)
    push.allowed_ips = "10.0.0.0/24"
    assert push.ip_allowed?("10.0.0.1")
    assert push.ip_allowed?("10.0.0.254")
    assert_not push.ip_allowed?("10.0.1.1")
  end

  test "ip_allowed? handles invalid IP gracefully" do
    push = pushes(:test_push)
    push.allowed_ips = "1.2.3.4"
    assert_not push.ip_allowed?("not-an-ip")
  end

  test "ip_allowed? handles invalid allowlist entry gracefully" do
    push = pushes(:test_push)
    push.allowed_ips = "not-valid, 1.2.3.4"
    assert push.ip_allowed?("1.2.3.4")
  end

  test "country_allowed? returns true when no restrictions" do
    push = pushes(:test_push)
    assert push.country_allowed?("1.2.3.4")
  end
end
