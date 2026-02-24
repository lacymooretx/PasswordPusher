# frozen_string_literal: true

class User < ApplicationRecord
  include Pwpush::TokenAuthentication

  # Include default devise modules.
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :trackable, :confirmable, :lockable, :timeoutable,
    :omniauthable

  has_many :pushes, dependent: :destroy
  has_many :requests, dependent: :destroy
  has_one :user_policy, dependent: :destroy
  has_one :user_branding, dependent: :destroy
  has_many :otp_backup_codes, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships
  has_many :owned_teams, class_name: "Team", foreign_key: :owner_id, dependent: :destroy

  has_encrypted :otp_secret

  attr_readonly :admin

  def admin?
    admin
  end

  # --- Two-Factor Authentication ---

  def otp_enabled?
    otp_required_for_login? && otp_secret.present?
  end

  def otp_provisioning_uri(account = email)
    return nil unless otp_secret.present?
    issuer = Settings.brand&.title || "PasswordPusher"
    totp = ROTP::TOTP.new(otp_secret, issuer: issuer)
    totp.provisioning_uri(account)
  end

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

  def disable_two_factor!
    update!(otp_required_for_login: false, otp_secret: nil, consumed_timestep: nil)
    otp_backup_codes.delete_all
  end

  # --- SSO / OmniAuth ---

  def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # Try to find existing user by email and link the SSO account
    user = find_by(email: auth.info.email)
    if user
      user.update!(provider: auth.provider, uid: auth.uid)
      return user
    end

    # Create new user with SSO credentials
    create!(
      email: auth.info.email,
      provider: auth.provider,
      uid: auth.uid,
      password: Devise.friendly_token[0, 30],
      confirmed_at: Time.current # SSO users are pre-confirmed
    )
  end

  def sso_user?
    provider.present? && uid.present?
  end
end
