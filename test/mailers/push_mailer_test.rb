# frozen_string_literal: true

require "test_helper"

class PushMailerTest < ActionMailer::TestCase
  test "push_viewed sends email" do
    push = pushes(:test_push)
    audit_log = push.audit_logs.create!(kind: :view, ip: "1.2.3.4", user_agent: "Test", referrer: "")
    email = PushMailer.push_viewed(push, audit_log)
    assert_equal ["giuliana@example.org"], email.to
    assert_equal "Your push was viewed", email.subject
  end

  test "push_expired sends email" do
    push = pushes(:test_push)
    email = PushMailer.push_expired(push)
    assert_equal ["giuliana@example.org"], email.to
    assert_equal "Your push has expired", email.subject
  end

  test "push_expiring_soon sends email" do
    push = pushes(:test_push)
    email = PushMailer.push_expiring_soon(push)
    assert_equal ["giuliana@example.org"], email.to
    assert_equal "Your push is expiring soon", email.subject
  end
end
