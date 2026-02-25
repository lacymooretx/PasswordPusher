# frozen_string_literal: true

require "test_helper"

class Api::V1::PushesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Settings.enable_logins = true
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

  # --- show ---

  def test_show_returns_push
    get "/p/testtoken123.json"
    assert_response :ok

    res = JSON.parse(@response.body)
    assert_equal "testtoken123", res["url_token"]
    assert res.key?("payload")
    assert res.key?("expired")
    assert_equal false, res["expired"]
  end

  def test_show_expired_push
    push = pushes(:test_push)
    push.expire!

    get "/p/testtoken123.json"
    assert_response :ok

    res = JSON.parse(@response.body)
    assert_equal true, res["expired"]
  end

  def test_show_not_found
    get "/p/nonexistent.json"
    assert_response :not_found

    res = JSON.parse(@response.body)
    assert_equal "not-found", res["error"]
  end

  # --- create ---

  def test_create_authenticated
    assert_difference "Push.count", 1 do
      post "/p.json",
        params: {password: {payload: "test-secret"}},
        headers: @auth_headers
    end
    assert_response :created

    res = JSON.parse(@response.body)
    assert res.key?("url_token")
    assert_equal false, res["expired"]
  end

  def test_create_anonymous
    Settings.allow_anonymous = true

    assert_difference "Push.count", 1 do
      post "/p.json", params: {password: {payload: "test-secret"}}
    end
    assert_response :created

    res = JSON.parse(@response.body)
    assert res.key?("url_token")
  end

  def test_create_requires_auth_when_anonymous_disabled
    Settings.allow_anonymous = false

    post "/p.json", params: {password: {payload: "test-secret"}}
    assert_response :unauthorized
  end

  # --- preview ---

  def test_preview
    get "/p/testtoken123/preview.json"
    assert_response :ok

    res = JSON.parse(@response.body)
    assert res.key?("url")
  end

  # --- audit ---

  def test_audit_with_owner
    get "/p/testtoken123/audit.json", headers: @auth_headers
    assert_response :ok

    res = JSON.parse(@response.body)
    assert res.key?("views")
  end

  def test_audit_without_auth
    get "/p/testtoken123/audit.json"
    assert_response :unauthorized
  end

  # --- destroy ---

  def test_destroy_by_owner
    delete "/p/testtoken123.json", headers: @auth_headers
    assert_response :ok

    res = JSON.parse(@response.body)
    assert_equal true, res["expired"]

    push = pushes(:test_push).reload
    assert push.expired
  end

  # --- active ---

  def test_active
    get "/p/active.json", headers: @auth_headers
    assert_response :ok

    res = JSON.parse(@response.body)
    assert_kind_of Array, res
  end

  # --- expired ---

  def test_expired
    get "/p/expired.json", headers: @auth_headers
    assert_response :ok

    res = JSON.parse(@response.body)
    assert_kind_of Array, res
  end
end
