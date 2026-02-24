# frozen_string_literal: true

require "test_helper"

class UserPoliciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @luca = users(:luca)
    Settings.enable_user_policies = true
  end

  teardown do
    Settings.enable_user_policies = false
  end

  test "should redirect to login when not authenticated" do
    get edit_user_policy_path
    assert_response :redirect
  end

  test "should get edit when authenticated" do
    sign_in @luca
    get edit_user_policy_path
    assert_response :success
  end

  test "should update user policy" do
    sign_in @luca
    patch user_policy_path, params: {
      user_policy: {
        pw_expire_after_days: 14,
        pw_expire_after_views: 10,
        pw_retrieval_step: true,
        pw_deletable_by_viewer: false
      }
    }
    assert_redirected_to edit_user_policy_path

    @luca.reload
    assert_equal 14, @luca.user_policy.pw_expire_after_days
    assert_equal 10, @luca.user_policy.pw_expire_after_views
  end

  test "should create policy if none exists" do
    giuliana = users(:giuliana)
    sign_in giuliana

    assert_nil giuliana.user_policy

    patch user_policy_path, params: {
      user_policy: {
        pw_expire_after_days: 30
      }
    }
    assert_redirected_to edit_user_policy_path

    giuliana.reload
    assert_not_nil giuliana.user_policy
    assert_equal 30, giuliana.user_policy.pw_expire_after_days
  end

  test "should reject invalid values" do
    sign_in @luca
    patch user_policy_path, params: {
      user_policy: {
        pw_expire_after_days: 9999
      }
    }
    assert_response :unprocessable_content
  end

  test "should redirect when feature is disabled" do
    Settings.enable_user_policies = false
    sign_in @luca
    get edit_user_policy_path
    assert_response :redirect
  end
end
