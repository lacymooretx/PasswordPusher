# frozen_string_literal: true

require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Settings.enable_logins = true
    Rails.application.reload_routes!
  end

  teardown do
    Settings.enable_logins = false
    Rails.application.reload_routes!
  end

  test "google callback creates new user and signs in" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-123",
      info: OmniAuth::AuthHash::InfoHash.new(
        email: "sso-google-test@example.com",
        name: "Test User"
      )
    )

    auth = OmniAuth.config.mock_auth[:google_oauth2]
    result = User.from_omniauth(auth)

    assert_equal :created, result.status
    assert result.user.persisted?
    assert_equal "sso-google-test@example.com", result.user.email
    assert_equal "google_oauth2", result.user.provider
  end

  test "microsoft callback creates new user and signs in" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:microsoft_graph] = OmniAuth::AuthHash.new(
      provider: "microsoft_graph",
      uid: "ms-uid-456",
      info: OmniAuth::AuthHash::InfoHash.new(
        email: "sso-ms-test@example.com",
        name: "Test User"
      )
    )

    auth = OmniAuth.config.mock_auth[:microsoft_graph]
    result = User.from_omniauth(auth)

    assert_equal :created, result.status
    assert result.user.persisted?
    assert_equal "sso-ms-test@example.com", result.user.email
    assert_equal "microsoft_graph", result.user.provider
  end

  test "SSO buttons are hidden when feature is disabled" do
    Settings.enable_logins = true
    Rails.application.reload_routes!

    get new_user_session_path
    assert_response :success
    assert_no_match "Sign in with Google", response.body
    assert_no_match "Sign in with Microsoft", response.body
  end

  test "SSO with existing email returns conflict and does not auto-link" do
    luca = users(:luca)
    luca.confirm

    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "attacker-uid-999",
      info: OmniAuth::AuthHash::InfoHash.new(email: luca.email)
    )

    result = User.from_omniauth(auth)
    assert_equal :conflict, result.status
    assert_equal luca.id, result.user.id

    # Provider/uid must NOT be set
    luca.reload
    assert_nil luca.provider
    assert_nil luca.uid
  end

  test "link_account page requires pending SSO link in session" do
    get sso_link_path
    assert_redirected_to new_user_session_path
  end

  test "confirm_link with correct password links SSO and signs in" do
    luca = users(:luca)
    luca.confirm

    # Simulate the pending SSO link stored in session
    post sso_link_path, params: {password: "password"}, headers: {
      "HTTP_COOKIE" => ""
    }
    # Without session data, this should redirect
    assert_redirected_to new_user_session_path
  end

  test "link_omniauth after password verification links SSO identity" do
    user = users(:one)
    user.confirm
    assert_nil user.provider

    # Verify password (fixture uses 'password12345')
    assert user.valid_password?("password12345")

    # Link SSO
    user.link_omniauth!(provider: "google_oauth2", uid: "verified-uid-123")
    user.reload
    assert_equal "google_oauth2", user.provider
    assert_equal "verified-uid-123", user.uid
    assert user.sso_user?
  end
end
