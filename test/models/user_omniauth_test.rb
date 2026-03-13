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

    result = User.from_omniauth(auth)
    assert_equal :found, result.status
    assert_equal @luca.id, result.user.id
  end

  test "from_omniauth returns conflict when email matches existing local account" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "new-uid-123",
      info: OmniAuth::AuthHash::InfoHash.new(email: @luca.email)
    )

    result = User.from_omniauth(auth)
    assert_equal :conflict, result.status
    assert_equal @luca.id, result.user.id
    # Provider/uid should NOT be updated yet
    @luca.reload
    assert_nil @luca.provider
    assert_nil @luca.uid
  end

  test "from_omniauth creates new user when no match found" do
    auth = OmniAuth::AuthHash.new(
      provider: "microsoft_graph",
      uid: "ms-uid-456",
      info: OmniAuth::AuthHash::InfoHash.new(email: "newuser@example.com")
    )

    assert_difference "User.count", 1 do
      result = User.from_omniauth(auth)
      assert_equal :created, result.status
      assert result.user.persisted?
      assert_equal "newuser@example.com", result.user.email
      assert_equal "microsoft_graph", result.user.provider
      assert_equal "ms-uid-456", result.user.uid
      assert result.user.confirmed_at.present? # SSO users are pre-confirmed
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

    result = User.from_omniauth(auth)
    assert_equal :found, result.status
    assert_equal @luca.id, result.user.id
  end

  test "link_omniauth! links SSO identity to existing account" do
    assert_nil @luca.provider
    assert_nil @luca.uid

    @luca.link_omniauth!(provider: "google_oauth2", uid: "linked-uid-789", avatar_url: "https://example.com/avatar.png")
    @luca.reload

    assert_equal "google_oauth2", @luca.provider
    assert_equal "linked-uid-789", @luca.uid
    assert_equal "https://example.com/avatar.png", @luca.avatar_url
  end
end
