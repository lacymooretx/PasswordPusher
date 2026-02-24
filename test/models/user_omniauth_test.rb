# frozen_string_literal: true

require "test_helper"

class UserOmniauthTest < ActiveSupport::TestCase
  setup do
    @luca = users(:luca)
  end

  test "sso_user? returns false by default" do
    assert_not @luca.sso_user?
  end

  test "sso_user? returns true when provider and uid set" do
    @luca.update!(provider: "google_oauth2", uid: "12345")
    assert @luca.sso_user?
  end

  test "from_omniauth finds existing user by provider and uid" do
    @luca.update!(provider: "google_oauth2", uid: "12345")

    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "12345",
      info: OmniAuth::AuthHash::InfoHash.new(email: @luca.email)
    )

    user = User.from_omniauth(auth)
    assert_equal @luca.id, user.id
  end

  test "from_omniauth links SSO to existing user by email" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "new-uid-123",
      info: OmniAuth::AuthHash::InfoHash.new(email: @luca.email)
    )

    user = User.from_omniauth(auth)
    assert_equal @luca.id, user.id
    assert_equal "google_oauth2", user.provider
    assert_equal "new-uid-123", user.uid
  end

  test "from_omniauth creates new user when no match found" do
    auth = OmniAuth::AuthHash.new(
      provider: "microsoft_graph",
      uid: "ms-uid-456",
      info: OmniAuth::AuthHash::InfoHash.new(email: "newuser@example.com")
    )

    assert_difference "User.count", 1 do
      user = User.from_omniauth(auth)
      assert user.persisted?
      assert_equal "newuser@example.com", user.email
      assert_equal "microsoft_graph", user.provider
      assert_equal "ms-uid-456", user.uid
      assert user.confirmed_at.present? # SSO users are pre-confirmed
    end
  end

  test "from_omniauth enforces uniqueness on provider and uid" do
    @luca.update!(provider: "google_oauth2", uid: "12345")

    # Trying to create another user with same provider+uid should find luca
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "12345",
      info: OmniAuth::AuthHash::InfoHash.new(email: "different@example.com")
    )

    user = User.from_omniauth(auth)
    assert_equal @luca.id, user.id
  end
end
