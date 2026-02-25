# frozen_string_literal: true

require "test_helper"

class Api::V1::UserPoliciesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Settings.enable_logins = true
    Settings.enable_user_policies = true
    Rails.application.reload_routes!

    @giuliana = users(:giuliana)
    @giuliana.confirm
    @auth_headers = {
      "X-User-Email" => @giuliana.email,
      "X-User-Token" => @giuliana.authentication_token
    }
  end

  teardown do
    Settings.reload!
    Rails.application.reload_routes!
  end

  def test_show_with_policy
    policy = UserPolicy.create!(user: @giuliana, pw_expire_after_days: 3, pw_expire_after_views: 2)

    get "/api/v1/user_policy.json", headers: @auth_headers
    assert_response :ok

    res = JSON.parse(@response.body)
    assert_equal 3, res["pw_expire_after_days"]
    assert_equal 2, res["pw_expire_after_views"]
  ensure
    policy&.destroy
  end

  def test_show_without_policy
    # Ensure no policy exists for giuliana
    UserPolicy.where(user: @giuliana).destroy_all

    get "/api/v1/user_policy.json", headers: @auth_headers
    assert_response :ok

    res = JSON.parse(@response.body)
    assert_equal({}, res)
  end

  def test_update
    put "/api/v1/user_policy.json",
      params: {user_policy: {pw_expire_after_days: 5, pw_expire_after_views: 3}},
      headers: @auth_headers
    assert_response :ok

    res = JSON.parse(@response.body)
    assert_equal 5, res["pw_expire_after_days"]
    assert_equal 3, res["pw_expire_after_views"]
  ensure
    UserPolicy.where(user: @giuliana).destroy_all
  end

  def test_feature_disabled
    Settings.enable_user_policies = false

    get "/api/v1/user_policy.json", headers: @auth_headers
    assert_response :not_found

    res = JSON.parse(@response.body)
    assert_equal "User policies are not enabled.", res["error"]
  end

  def test_unauthenticated
    get "/api/v1/user_policy.json"
    assert_response :unauthorized
  end
end
