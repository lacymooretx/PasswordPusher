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

  test "push_dispatched sends email to recipient" do
    push = pushes(:test_push)
    secret_url = "https://pwpush.test/p/#{push.url_token}"
    email = PushMailer.push_dispatched(push, secret_url, "recipient@example.com")
    assert_equal ["recipient@example.com"], email.to
    assert_equal "A secret has been shared with you", email.subject
    assert_match secret_url, email.body.encoded
  end

  test "push_dispatched includes push name when present" do
    push = pushes(:test_push)
    push.name = "Server Credentials"
    secret_url = "https://pwpush.test/p/#{push.url_token}"
    email = PushMailer.push_dispatched(push, secret_url, "recipient@example.com")
    assert_match "Server Credentials", email.body.encoded
  end
end
