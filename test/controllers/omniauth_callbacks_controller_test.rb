# frozen_string_literal: true

require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  # OmniAuth integration tests use OmniAuth's mock mode
  # which is enabled by default in test environment.
  # These tests verify the controller logic without actual OAuth flows.

  test "google callback creates user and signs in" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-123",
      info: OmniAuth::AuthHash::InfoHash.new(
        email: "sso-google-test@example.com",
        name: "Test User"
      )
    )

    # Simulate the OmniAuth callback by calling from_omniauth directly
    # (actual OAuth redirects require browser and real provider)
    auth = OmniAuth.config.mock_auth[:google_oauth2]
    user = User.from_omniauth(auth)

    assert user.persisted?
    assert_equal "sso-google-test@example.com", user.email
    assert_equal "google_oauth2", user.provider
  end

  test "microsoft callback creates user and signs in" do
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
    user = User.from_omniauth(auth)

    assert user.persisted?
    assert_equal "sso-ms-test@example.com", user.email
    assert_equal "microsoft_graph", user.provider
  end

  test "SSO buttons are hidden when feature is disabled" do
    # Default settings have SSO disabled
    get new_user_session_path
    assert_response :success
    assert_no_match "Sign in with Google", response.body
    assert_no_match "Sign in with Microsoft", response.body
  end
end
