# frozen_string_literal: true

require "test_helper"

class TwoFactorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one) # password: password12345
    Settings.enable_two_factor = true
  end

  teardown do
    Settings.enable_two_factor = false
  end

  test "setup requires authentication" do
    get setup_users_two_factor_path
    assert_response :redirect
  end

  test "setup page loads when authenticated" do
    sign_in @user
    get setup_users_two_factor_path
    assert_response :success
  end

  test "setup generates otp secret" do
    sign_in @user
    assert_nil @user.otp_secret

    get setup_users_two_factor_path
    @user.reload
    assert @user.otp_secret.present?
  end

  test "enable with valid code succeeds" do
    sign_in @user
    @user.generate_otp_secret!
    totp = ROTP::TOTP.new(@user.otp_secret)

    post enable_users_two_factor_path, params: {otp_code: totp.now}
    @user.reload

    assert @user.otp_enabled?
    assert @user.otp_backup_codes.count > 0
    assert_response :success # renders backup_codes view
  end

  test "enable with invalid code re-renders setup" do
    sign_in @user
    @user.generate_otp_secret!

    post enable_users_two_factor_path, params: {otp_code: "000000"}
    @user.reload

    assert_not @user.otp_enabled?
    assert_response :success # re-renders setup
  end

  test "disable with valid password succeeds" do
    sign_in @user
    @user.generate_otp_secret!
    @user.enable_two_factor!

    delete disable_users_two_factor_path, params: {password: "password12345"}
    @user.reload

    assert_not @user.otp_enabled?
    assert_redirected_to edit_user_registration_path
  end

  test "disable with invalid password fails" do
    sign_in @user
    @user.generate_otp_secret!
    @user.enable_two_factor!

    delete disable_users_two_factor_path, params: {password: "wrongpassword"}
    @user.reload

    assert @user.otp_enabled?
    assert_redirected_to edit_user_registration_path
  end

  test "regenerate backup codes works" do
    sign_in @user
    @user.generate_otp_secret!
    @user.enable_two_factor!
    OtpBackupCode.generate_for(@user)

    get regenerate_backup_codes_users_two_factor_path
    assert_response :success
  end

  test "redirects when feature is disabled" do
    Settings.enable_two_factor = false
    sign_in @user

    get setup_users_two_factor_path
    assert_response :redirect
  end
end
