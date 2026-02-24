# frozen_string_literal: true

# Manages 2FA setup lifecycle: shows QR code for TOTP enrollment, verifies
# the initial OTP to enable, disables after password confirmation, and
# regenerates backup codes. Requires Settings.enable_two_factor.
class Users::TwoFactorController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled

  # GET /users/two_factor/setup
  # Shows QR code and manual key for TOTP setup
  def setup
    current_user.generate_otp_secret! unless current_user.otp_secret.present?

    @qr_code = generate_qr_code(current_user.otp_provisioning_uri)
    @otp_secret = current_user.otp_secret
  end

  # POST /users/two_factor/enable
  # Verifies OTP code and enables 2FA
  def enable
    if current_user.verify_otp(params[:otp_code])
      current_user.enable_two_factor!
      @backup_codes = OtpBackupCode.generate_for(current_user)
      render :backup_codes
    else
      current_user.generate_otp_secret! unless current_user.otp_secret.present?
      @qr_code = generate_qr_code(current_user.otp_provisioning_uri)
      @otp_secret = current_user.otp_secret
      flash.now[:alert] = I18n._("Invalid verification code. Please try again.")
      render :setup
    end
  end

  # DELETE /users/two_factor/disable
  # Disables 2FA after password confirmation
  def disable
    if current_user.valid_password?(params[:password])
      current_user.disable_two_factor!
      redirect_to edit_user_registration_path, notice: I18n._("Two-factor authentication has been disabled.")
    else
      redirect_to edit_user_registration_path, alert: I18n._("Incorrect password.")
    end
  end

  # GET /users/two_factor/backup_codes
  # Regenerates and displays new backup codes
  def regenerate_backup_codes
    @backup_codes = OtpBackupCode.generate_for(current_user)
    render :backup_codes
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_two_factor) && Settings.enable_two_factor
      redirect_to root_path, notice: I18n._("This feature is not enabled.")
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
