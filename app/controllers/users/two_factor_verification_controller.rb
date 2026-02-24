# frozen_string_literal: true

class Users::TwoFactorVerificationController < ApplicationController
  layout "login"

  before_action :check_feature_enabled
  before_action :require_otp_user

  # Provide Devise helpers needed by the login layout's shared links partial
  helper_method :resource_name, :resource, :resource_class, :devise_mapping

  def resource_name
    :user
  end

  def resource
    @resource ||= User.new
  end

  def resource_class
    User
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end

  # GET /users/two_factor_verification/new
  def new
    # Show OTP input form
  end

  # POST /users/two_factor_verification
  def create
    user = User.find(session[:otp_user_id])

    if user.verify_otp(params[:otp_code]) || user.verify_otp_backup_code(params[:otp_code])
      # Clear OTP session data
      remember_me = session.delete(:otp_remember_me)
      session.delete(:otp_user_id)

      # Complete sign-in
      user.remember_me = remember_me == "1"
      sign_in(:user, user)
      redirect_to after_sign_in_path_for(user)
    else
      flash.now[:alert] = I18n._("Invalid verification code. Please try again.")
      render :new, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_two_factor) && Settings.enable_two_factor
      redirect_to new_user_session_path
    end
  end

  def require_otp_user
    unless session[:otp_user_id].present?
      redirect_to new_user_session_path, alert: I18n._("Please sign in first.")
    end
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end
end
