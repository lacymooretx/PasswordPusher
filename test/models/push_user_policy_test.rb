# frozen_string_literal: true

require "test_helper"

class PushUserPolicyTest < ActiveSupport::TestCase
  setup do
    @luca = users(:luca)
    Settings.enable_user_policies = true
  end

  teardown do
    Settings.enable_user_policies = false
  end

  test "push uses user policy expire_after_days when set" do
    push = Push.new(
      kind: "text",
      payload: "test_payload",
      user: @luca
    )
    push.save!

    # luca's policy has pw_expire_after_days: 14
    assert_equal 14, push.expire_after_days
  end

  test "push uses user policy expire_after_views when set" do
    push = Push.new(
      kind: "text",
      payload: "test_payload",
      user: @luca
    )
    push.save!

    # luca's policy has pw_expire_after_views: 10
    assert_equal 10, push.expire_after_views
  end

  test "push uses global default when user policy is disabled" do
    Settings.enable_user_policies = false

    push = Push.new(
      kind: "text",
      payload: "test_payload",
      user: @luca
    )
    push.save!

    assert_equal Settings.pw.expire_after_days_default, push.expire_after_days
    assert_equal Settings.pw.expire_after_views_default, push.expire_after_views
  end

  test "push uses global default when user has no policy" do
    giuliana = users(:giuliana)

    push = Push.new(
      kind: "text",
      payload: "test_payload",
      user: giuliana
    )
    push.save!

    assert_equal Settings.pw.expire_after_days_default, push.expire_after_days
    assert_equal Settings.pw.expire_after_views_default, push.expire_after_views
  end

  test "push uses global default for anonymous pushes" do
    push = Push.new(
      kind: "text",
      payload: "test_payload"
    )
    push.save!

    assert_equal Settings.pw.expire_after_days_default, push.expire_after_days
    assert_equal Settings.pw.expire_after_views_default, push.expire_after_views
  end

  test "push enforces global max even with user policy" do
    # Update luca's policy to have a value above global max
    @luca.user_policy.update!(pw_expire_after_days: Settings.pw.expire_after_days_max)

    push = Push.new(
      kind: "text",
      payload: "test_payload",
      user: @luca
    )
    push.save!

    assert push.expire_after_days <= Settings.pw.expire_after_days_max
  end

  test "user_policy_kind_key maps correctly" do
    push = Push.new(kind: "text")
    assert_equal :pw, push.user_policy_kind_key

    push = Push.new(kind: "url")
    assert_equal :url, push.user_policy_kind_key

    push = Push.new(kind: "file")
    assert_equal :file, push.user_policy_kind_key

    push = Push.new(kind: "qr")
    assert_equal :qr, push.user_policy_kind_key
  end
end
