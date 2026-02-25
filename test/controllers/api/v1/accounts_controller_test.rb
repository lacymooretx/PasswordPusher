# frozen_string_literal: true

require "test_helper"

class Api::V1::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_logins = true
    @user = users(:giuliana)
    sign_in @user
    ActionMailer::Base.default_url_options = {host: "localhost", port: 5100}
    Devise.mailer_sender = "test@example.com"
  end

  teardown do
    Settings.enable_logins = false
    Settings.disable_signups = false
  end

  # --- register ---

  test "register creates new user" do
    sign_out @user
    assert_difference("User.count", 1) do
      post register_api_v1_account_path(format: :json), params: {
        email: "newuser@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "newuser@example.com", json["email"]
    assert json.key?("token")
  end

  test "register does not require auth" do
    sign_out @user
    post register_api_v1_account_path(format: :json), params: {
      email: "noauth@example.com",
      password: "securepassword123",
      password_confirmation: "securepassword123"
    }
    assert_response :created
  end

  test "register fails when logins disabled" do
    Settings.enable_logins = false
    sign_out @user
    post register_api_v1_account_path(format: :json), params: {
      email: "disabled@example.com",
      password: "securepassword123",
      password_confirmation: "securepassword123"
    }
    assert_response :not_found
  end

  test "register fails when signups disabled" do
    Settings.disable_signups = true
    sign_out @user
    post register_api_v1_account_path(format: :json), params: {
      email: "nosignup@example.com",
      password: "securepassword123",
      password_confirmation: "securepassword123"
    }
    assert_response :forbidden
  end

  test "register fails with duplicate email" do
    sign_out @user
    post register_api_v1_account_path(format: :json), params: {
      email: @user.email,
      password: "securepassword123",
      password_confirmation: "securepassword123"
    }
    assert_response :unprocessable_content
  end

  # --- show ---

  test "show returns user profile" do
    get api_v1_account_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @user.email, json["email"]
    assert json.key?("admin")
    assert json.key?("otp_enabled")
    assert json.key?("token")
  end

  test "show requires authentication" do
    sign_out @user
    get api_v1_account_path(format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end

  # --- update ---

  test "update changes preferred language" do
    patch api_v1_account_path(format: :json), params: {preferred_language: "fr"}
    assert_response :success
    @user.reload
    assert_equal "fr", @user.preferred_language
  end

  # --- change_password ---

  test "change password succeeds with correct current password" do
    # Use a user with known password
    user = users(:one)
    sign_in user
    patch password_api_v1_account_path(format: :json), params: {
      current_password: "password12345",
      password: "newsecurepassword123",
      password_confirmation: "newsecurepassword123"
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Password updated successfully", json["message"]
  end

  test "change password fails with wrong current password" do
    patch password_api_v1_account_path(format: :json), params: {
      current_password: "wrongpassword",
      password: "newsecurepassword123",
      password_confirmation: "newsecurepassword123"
    }
    assert_response :unprocessable_content
  end

  # --- destroy ---

  test "delete account fails with wrong password" do
    delete api_v1_account_path(format: :json), params: {password: "wrongpassword"}
    assert_response :unprocessable_content
  end

  # --- regenerate_token ---

  test "regenerate token returns new token" do
    old_token = @user.authentication_token
    post token_api_v1_account_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("token")
    assert_not_equal old_token, json["token"]
  end

  # --- token auth ---

  test "token auth works for show" do
    sign_out @user
    get api_v1_account_path(format: :json),
      headers: {"X-User-Email" => @user.email, "X-User-Token" => @user.authentication_token}
    assert_response :success
  end
end
