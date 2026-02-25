# frozen_string_literal: true

require "test_helper"

class Api::V1::TwoFactorControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_two_factor = true
    @user = users(:giuliana)
    sign_in @user
  end

  teardown do
    Settings.enable_two_factor = false
    @user.reload
    if @user.otp_secret.present?
      @user.disable_two_factor!
    end
  end

  # --- setup ---

  test "setup returns otp_secret and qr_svg" do
    post setup_api_v1_account_two_factor_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("otp_secret")
    assert json.key?("provisioning_uri")
    assert json.key?("qr_svg")
    assert json["otp_secret"].present?
    assert json["qr_svg"].include?("<svg")
  end

  # --- enable ---

  test "enable with valid OTP returns backup codes" do
    @user.generate_otp_secret!
    totp = ROTP::TOTP.new(@user.otp_secret)
    valid_code = totp.now

    post enable_api_v1_account_two_factor_path(format: :json), params: {otp_code: valid_code}
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Two-factor authentication enabled", json["message"]
    assert json["backup_codes"].is_a?(Array)
    assert_equal 10, json["backup_codes"].length
  end

  test "enable with invalid OTP returns 422" do
    @user.generate_otp_secret!
    post enable_api_v1_account_two_factor_path(format: :json), params: {otp_code: "000000"}
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_equal "Invalid verification code", json["error"]
  end

  # --- disable ---

  test "disable with correct password succeeds" do
    user = users(:one)
    sign_in user
    user.generate_otp_secret!
    user.enable_two_factor!

    delete "/api/v1/account/two_factor.json", params: {password: "password12345"}
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Two-factor authentication disabled", json["message"]
  end

  test "disable with wrong password returns 422" do
    @user.generate_otp_secret!
    @user.enable_two_factor!

    delete "/api/v1/account/two_factor.json", params: {password: "wrongpassword"}
    assert_response :unprocessable_content
  end

  # --- regenerate_backup_codes ---

  test "regenerate backup codes when 2FA enabled" do
    @user.generate_otp_secret!
    @user.enable_two_factor!

    post backup_codes_api_v1_account_two_factor_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json["backup_codes"].is_a?(Array)
    assert_equal 10, json["backup_codes"].length
  end

  test "regenerate backup codes when 2FA not enabled returns 422" do
    post backup_codes_api_v1_account_two_factor_path(format: :json)
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_equal "Two-factor authentication is not enabled", json["error"]
  end

  # --- feature disabled ---

  test "feature disabled returns not found" do
    Settings.enable_two_factor = false
    post setup_api_v1_account_two_factor_path(format: :json)
    assert_response :not_found
  end

  # --- unauthenticated ---

  test "unauthenticated returns unauthorized" do
    sign_out @user
    post setup_api_v1_account_two_factor_path(format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end
end
