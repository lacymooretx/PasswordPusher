# frozen_string_literal: true

# JSON API for managing two-factor authentication. Token-authenticated via
# Api::BaseController. Requires Settings.enable_two_factor.
class Api::V1::TwoFactorController < Api::BaseController
  before_action :check_feature_enabled

  resource_description do
    name "Two-Factor Authentication"
    short "Manage 2FA for your account."
  end

  api :POST, "/api/v1/account/two_factor/setup.json", "Start 2FA setup."
  formats ["JSON"]
  description <<-EOS
    Generates a new TOTP secret and returns the provisioning URI and QR code
    SVG for scanning with an authenticator app.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Two-factor authentication feature is not enabled."
  def setup
    current_user.generate_otp_secret! unless current_user.otp_secret.present?

    qr_svg = generate_qr_code(current_user.otp_provisioning_uri)

    render json: {
      otp_secret: current_user.otp_secret,
      provisioning_uri: current_user.otp_provisioning_uri,
      qr_svg: qr_svg
    }
  end

  api :POST, "/api/v1/account/two_factor/enable.json", "Enable 2FA."
  param :otp_code, String, desc: "TOTP code from authenticator app.", required: true
  formats ["JSON"]
  description <<-EOS
    Verifies the TOTP code and enables 2FA. Returns backup codes that should
    be stored securely for account recovery.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Two-factor authentication feature is not enabled."
  error code: 422, desc: "Invalid OTP code."
  def enable
    unless current_user.verify_otp(params[:otp_code])
      render json: {error: "Invalid verification code"}, status: :unprocessable_content
      return
    end

    current_user.enable_two_factor!
    backup_codes = OtpBackupCode.generate_for(current_user)

    render json: {
      message: "Two-factor authentication enabled",
      backup_codes: backup_codes
    }
  end

  api :DELETE, "/api/v1/account/two_factor.json", "Disable 2FA."
  param :password, String, desc: "Your current password for confirmation.", required: true
  formats ["JSON"]
  description <<-EOS
    Disables two-factor authentication. Requires password confirmation.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Two-factor authentication feature is not enabled."
  error code: 422, desc: "Invalid password."
  def disable
    unless current_user.valid_password?(params[:password])
      render json: {error: "Password is incorrect"}, status: :unprocessable_content
      return
    end

    current_user.disable_two_factor!
    render json: {message: "Two-factor authentication disabled"}
  end

  api :POST, "/api/v1/account/two_factor/backup_codes.json", "Regenerate backup codes."
  formats ["JSON"]
  description <<-EOS
    Generates a new set of backup codes, invalidating all previous ones.
    Requires 2FA to be enabled.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Two-factor authentication feature is not enabled."
  error code: 422, desc: "2FA not enabled on account."
  def regenerate_backup_codes
    unless current_user.otp_enabled?
      render json: {error: "Two-factor authentication is not enabled"}, status: :unprocessable_content
      return
    end

    backup_codes = OtpBackupCode.generate_for(current_user)
    render json: {backup_codes: backup_codes}
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_two_factor) && Settings.enable_two_factor
      render json: {error: "Two-factor authentication is not enabled"}, status: :not_found
    end
  end

  def generate_qr_code(uri)
    qrcode = RQRCode::QRCode.new(uri)
    qrcode.as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      use_path: true
    )
  end
end
