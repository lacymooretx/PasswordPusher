# frozen_string_literal: true

require "test_helper"

class UserTwoFactorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "otp_enabled? returns false by default" do
    assert_not @user.otp_enabled?
  end

  test "generate_otp_secret! creates a secret" do
    @user.generate_otp_secret!
    assert @user.otp_secret.present?
  end

  test "otp_provisioning_uri generates valid uri" do
    @user.generate_otp_secret!
    uri = @user.otp_provisioning_uri
    assert uri.present?
    assert uri.start_with?("otpauth://totp/")
    # Email may be URI-encoded (@ -> %40)
    assert uri.include?("one") # username part of email
  end

  test "verify_otp validates correct code" do
    @user.generate_otp_secret!
    totp = ROTP::TOTP.new(@user.otp_secret)
    code = totp.now

    assert @user.verify_otp(code)
  end

  test "verify_otp rejects invalid code" do
    @user.generate_otp_secret!
    assert_not @user.verify_otp("000000")
  end

  test "verify_otp rejects replay (same timestep)" do
    @user.generate_otp_secret!
    totp = ROTP::TOTP.new(@user.otp_secret)
    code = totp.now

    assert @user.verify_otp(code)
    assert_not @user.verify_otp(code) # replay
  end

  test "enable_two_factor! sets otp_required_for_login" do
    @user.generate_otp_secret!
    @user.enable_two_factor!

    assert @user.otp_required_for_login?
    assert @user.otp_enabled?
  end

  test "disable_two_factor! clears all 2FA data" do
    @user.generate_otp_secret!
    @user.enable_two_factor!
    OtpBackupCode.generate_for(@user)

    assert @user.otp_backup_codes.count > 0

    @user.disable_two_factor!

    assert_not @user.otp_required_for_login?
    assert_nil @user.otp_secret
    assert_nil @user.consumed_timestep
    assert_equal 0, @user.otp_backup_codes.count
  end

  test "verify_otp_backup_code works with valid code" do
    @user.generate_otp_secret!
    codes = OtpBackupCode.generate_for(@user)

    assert @user.verify_otp_backup_code(codes.first)
  end

  test "verify_otp_backup_code rejects used code" do
    @user.generate_otp_secret!
    codes = OtpBackupCode.generate_for(@user)

    assert @user.verify_otp_backup_code(codes.first)
    assert_not @user.verify_otp_backup_code(codes.first) # already used
  end

  test "verify_otp_backup_code rejects invalid code" do
    @user.generate_otp_secret!
    OtpBackupCode.generate_for(@user)

    assert_not @user.verify_otp_backup_code("invalidcode")
  end

  test "OtpBackupCode.generate_for creates 10 codes" do
    codes = OtpBackupCode.generate_for(@user)

    assert_equal 10, codes.length
    assert_equal 10, @user.otp_backup_codes.count
  end

  test "OtpBackupCode.generate_for replaces existing codes" do
    OtpBackupCode.generate_for(@user)
    old_ids = @user.otp_backup_codes.pluck(:id)

    OtpBackupCode.generate_for(@user)
    new_ids = @user.otp_backup_codes.reload.pluck(:id)

    assert_empty old_ids & new_ids
  end

  test "destroying user destroys backup codes" do
    OtpBackupCode.generate_for(@user)
    assert @user.otp_backup_codes.count > 0

    @user.destroy
    assert_equal 0, OtpBackupCode.where(user_id: @user.id).count
  end
end
