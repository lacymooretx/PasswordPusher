# frozen_string_literal: true

require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  setup do
    @luca = users(:luca)
  end

  test "should create user policy" do
    policy = UserPolicy.new(
      user: users(:giuliana),
      pw_expire_after_days: 14,
      pw_expire_after_views: 10
    )
    assert policy.save
  end

  test "should enforce uniqueness per user" do
    # luca already has a policy from fixtures
    duplicate = UserPolicy.new(user: @luca, pw_expire_after_days: 7)
    assert_not duplicate.valid?
  end

  test "default_for returns value when set" do
    policy = user_policies(:luca_policy)
    assert_equal 14, policy.default_for(:pw, :expire_after_days)
    assert_equal 10, policy.default_for(:pw, :expire_after_views)
    assert_equal true, policy.default_for(:pw, :retrieval_step)
    assert_equal false, policy.default_for(:pw, :deletable_by_viewer)
  end

  test "default_for returns nil when not set" do
    policy = UserPolicy.new(user: users(:giuliana))
    assert_nil policy.default_for(:pw, :expire_after_days)
    assert_nil policy.default_for(:pw, :expire_after_views)
  end

  test "default_for returns nil for invalid column" do
    policy = user_policies(:luca_policy)
    assert_nil policy.default_for(:pw, :nonexistent_attribute)
  end

  test "validates days within global limits" do
    policy = UserPolicy.new(
      user: users(:giuliana),
      pw_expire_after_days: 999
    )
    assert_not policy.valid?
    assert policy.errors[:pw_expire_after_days].any?
  end

  test "validates views within global limits" do
    policy = UserPolicy.new(
      user: users(:giuliana),
      pw_expire_after_views: 999
    )
    assert_not policy.valid?
    assert policy.errors[:pw_expire_after_views].any?
  end

  test "allows valid values within global limits" do
    policy = UserPolicy.new(
      user: users(:giuliana),
      pw_expire_after_days: Settings.pw.expire_after_days_min,
      pw_expire_after_views: Settings.pw.expire_after_views_min
    )
    assert policy.valid?
  end

  test "user has_one user_policy" do
    assert_equal user_policies(:luca_policy), @luca.user_policy
  end

  test "destroying user destroys policy" do
    policy_id = @luca.user_policy.id
    @luca.destroy
    assert_nil UserPolicy.find_by(id: policy_id)
  end
end
