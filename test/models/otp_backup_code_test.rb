# frozen_string_literal: true

require "test_helper"

class OtpBackupCodeTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "generate_for creates 10 codes by default" do
    codes = OtpBackupCode.generate_for(@user)

    assert_equal 10, codes.length
    assert_equal 10, @user.otp_backup_codes.count
  end

  test "generate_for replaces existing codes" do
    first_codes = OtpBackupCode.generate_for(@user)
    assert_equal 10, @user.otp_backup_codes.count

    second_codes = OtpBackupCode.generate_for(@user)
    assert_equal 10, @user.otp_backup_codes.count

    # The plaintext codes should be different sets
    assert_not_equal first_codes.sort, second_codes.sort
  end

  test "generate_for respects custom count" do
    codes = OtpBackupCode.generate_for(@user, count: 5)

    assert_equal 5, codes.length
    assert_equal 5, @user.otp_backup_codes.count
  end

  test "verify returns true for correct code and marks it used" do
    codes = OtpBackupCode.generate_for(@user)
    backup = @user.otp_backup_codes.first
    plaintext = codes.first

    assert backup.verify(plaintext)
    assert backup.reload.used?
  end

  test "verify returns false for incorrect code" do
    OtpBackupCode.generate_for(@user)
    backup = @user.otp_backup_codes.first

    assert_not backup.verify("wrongcode")
    assert_not backup.reload.used?
  end

  test "verify returns false for already-used code" do
    codes = OtpBackupCode.generate_for(@user)
    backup = @user.otp_backup_codes.first
    plaintext = codes.first

    # First use succeeds
    assert backup.verify(plaintext)
    assert backup.reload.used?

    # Second use fails
    assert_not backup.verify(plaintext)
  end

  test "generated codes are 8 characters hex" do
    codes = OtpBackupCode.generate_for(@user)

    codes.each do |code|
      assert_equal 8, code.length, "Code '#{code}' should be 8 characters"
      assert_match(/\A[0-9a-f]{8}\z/, code, "Code '#{code}' should be hex")
    end
  end

  test "belongs_to user" do
    OtpBackupCode.generate_for(@user)
    backup = @user.otp_backup_codes.first

    assert_equal @user, backup.user
  end
end
