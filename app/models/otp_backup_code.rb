# frozen_string_literal: true

# One-time-use backup codes for 2FA recovery. Each code is stored as a
# BCrypt digest so plaintext is never persisted. Codes are displayed once
# at generation time and marked as used on successful verification.
class OtpBackupCode < ApplicationRecord
  belongs_to :user

  # Verify a plaintext code against stored digest.
  # Returns true and marks code as used if valid.
  def verify(plaintext_code)
    return false if used?
    return false unless BCrypt::Password.new(code_digest) == plaintext_code

    update!(used: true)
    true
  end

  # Generate a set of backup codes for a user, replacing any existing ones.
  def self.generate_for(user, count: 10)
    user.otp_backup_codes.delete_all

    codes = count.times.map { SecureRandom.hex(4) } # 8-char hex codes
    codes.each do |code|
      user.otp_backup_codes.create!(code_digest: BCrypt::Password.create(code))
    end
    codes # Return plaintext codes for one-time display
  end
end
