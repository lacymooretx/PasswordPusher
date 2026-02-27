# frozen_string_literal: true

# Devise-based user account with optional 2FA (TOTP + backup codes),
# SSO via OmniAuth, team memberships, per-user push policy, and branding.
class User < ApplicationRecord
  include Pwpush::TokenAuthentication

  # Include default devise modules.
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :trackable, :confirmable, :lockable, :timeoutable,
    :omniauthable

  # --- Associations ---

  has_many :pushes, dependent: :destroy
  has_many :requests, dependent: :destroy
  has_one :user_policy, dependent: :destroy
  has_one :user_branding, dependent: :destroy
  has_many :otp_backup_codes, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships
  has_many :owned_teams, class_name: "Team", foreign_key: :owner_id, dependent: :destroy
  has_many :webhooks, dependent: :destroy

  has_encrypted :otp_secret

  attr_readonly :admin

  def admin?
    admin
  end

  # --- Two-Factor Authentication ---
  # TOTP-based 2FA using ROTP. The otp_secret is Lockbox-encrypted at rest.
  # Backup codes provide one-time-use recovery when the authenticator is unavailable.

  # Returns true if the user has 2FA fully configured and required at login.
  def otp_enabled?
    otp_required_for_login? && otp_secret.present?
  end

  def otp_provisioning_uri(account = email)
    return nil unless otp_secret.present?
    issuer = Settings.brand&.title || "PasswordPusher"
    totp = ROTP::TOTP.new(otp_secret, issuer: issuer)
    totp.provisioning_uri(account)
  end

  # Validates a TOTP code with +/-15 second drift tolerance.
  # Records the consumed timestep to prevent replay attacks.
  def verify_otp(code)
    return false unless otp_secret.present?

    totp = ROTP::TOTP.new(otp_secret)
    timestamp = totp.verify(code.to_s.gsub(/\s/, ""), drift_behind: 15, drift_ahead: 15, after: consumed_timestep)
    if timestamp
      update!(consumed_timestep: timestamp)
      true
    else
      false
    end
  end

  # Checks a one-time backup code against unused codes. Marks as used on match.
  def verify_otp_backup_code(code)
    plaintext = code.to_s.gsub(/\s/, "").downcase
    otp_backup_codes.where(used: false).find_each do |backup|
      return true if backup.verify(plaintext)
    end
    false
  end

  def generate_otp_secret!
    update!(otp_secret: ROTP::Base32.random)
  end

  def enable_two_factor!
    update!(otp_required_for_login: true)
  end

  # Fully removes 2FA: clears secret, consumed timestep, and all backup codes.
  def disable_two_factor!
    update!(otp_required_for_login: false, otp_secret: nil, consumed_timestep: nil)
    otp_backup_codes.delete_all
  end

  # --- SSO / OmniAuth ---
  # Supports linking SSO identities to existing accounts by matching email.

  # Finds or creates a user from an OmniAuth callback hash.
  # Priority: match by provider+uid, then by email (links SSO to existing account),
  # then create a new pre-confirmed user with a random password.
  def self.from_omniauth(auth)
    avatar = auth.info.image

    user = find_by(provider: auth.provider, uid: auth.uid)
    if user
      user.update!(avatar_url: avatar) if avatar.present? && user.avatar_url != avatar
      return user
    end

    # Try to find existing user by email and link the SSO account
    user = find_by(email: auth.info.email)
    if user
      user.update!(provider: auth.provider, uid: auth.uid, avatar_url: avatar)
      return user
    end

    # Create new user with SSO credentials
    create!(
      email: auth.info.email,
      provider: auth.provider,
      uid: auth.uid,
      avatar_url: avatar,
      password: Devise.friendly_token[0, 30],
      confirmed_at: Time.current # SSO users are pre-confirmed
    )
  end

  # Returns true if this account was created/linked via an SSO provider.
  def sso_user?
    provider.present? && uid.present?
  end
end
