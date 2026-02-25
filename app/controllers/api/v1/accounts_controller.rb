# frozen_string_literal: true

# JSON API for managing user accounts. Token-authenticated via Api::BaseController.
# Registration endpoint is public (no auth required). Respects enable_logins and
# disable_signups feature flags.
class Api::V1::AccountsController < Api::BaseController
  skip_before_action :require_api_authentication, only: [:register]

  resource_description do
    name "Account"
    short "Manage your user account."
  end

  api :POST, "/api/v1/account/register.json", "Register a new account."
  param :email, String, desc: "Email address for the new account.", required: true
  param :password, String, desc: "Password (minimum 8 characters).", required: true
  param :password_confirmation, String, desc: "Password confirmation.", required: true
  formats ["JSON"]
  description <<-EOS
    Creates a new user account. Returns the user profile with API token.
    Respects the disable_signups and enable_logins settings.
  EOS
  error code: 403, desc: "Signups are disabled."
  error code: 404, desc: "User registration is not enabled."
  error code: 422, desc: "Validation failed."
  def register
    unless Settings.respond_to?(:enable_logins) && Settings.enable_logins
      render json: {error: "User registration is not enabled"}, status: :not_found
      return
    end

    if Settings.respond_to?(:disable_signups) && Settings.disable_signups
      render json: {error: "New registrations are currently disabled"}, status: :forbidden
      return
    end

    user = User.new(
      email: params[:email],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )

    if user.save
      render json: account_json(user), status: :created
    else
      render json: {errors: user.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :GET, "/api/v1/account.json", "Get your account profile."
  formats ["JSON"]
  description <<-EOS
    Returns the authenticated user's account information including email,
    admin status, 2FA status, and API token.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  def show
    render json: account_json(current_user)
  end

  api :PATCH, "/api/v1/account.json", "Update your account."
  param :email, String, desc: "New email address."
  param :preferred_language, String, desc: "Preferred language code (e.g. 'en', 'fr')."
  formats ["JSON"]
  description <<-EOS
    Updates the authenticated user's account information.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 422, desc: "Validation failed."
  def update
    if current_user.update(account_update_params)
      render json: account_json(current_user)
    else
      render json: {errors: current_user.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :PATCH, "/api/v1/account/password.json", "Change your password."
  param :current_password, String, desc: "Your current password.", required: true
  param :password, String, desc: "New password.", required: true
  param :password_confirmation, String, desc: "New password confirmation.", required: true
  formats ["JSON"]
  description <<-EOS
    Changes the authenticated user's password. Requires current password.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 422, desc: "Invalid current password or validation failed."
  def change_password
    unless current_user.valid_password?(params[:current_password])
      render json: {error: "Current password is incorrect"}, status: :unprocessable_content
      return
    end

    if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      render json: {message: "Password updated successfully"}
    else
      render json: {errors: current_user.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :DELETE, "/api/v1/account.json", "Delete your account."
  param :password, String, desc: "Your current password for confirmation.", required: true
  formats ["JSON"]
  description <<-EOS
    Permanently deletes the authenticated user's account and all associated data.
    Requires password confirmation.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 422, desc: "Invalid password."
  def destroy
    unless current_user.valid_password?(params[:password])
      render json: {error: "Password is incorrect"}, status: :unprocessable_content
      return
    end

    current_user.destroy
    head :no_content
  end

  api :POST, "/api/v1/account/token.json", "Regenerate your API token."
  formats ["JSON"]
  description <<-EOS
    Generates a new API token, invalidating the previous one. The new token
    is returned in the response.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  def regenerate_token
    current_user.regenerate_authentication_token!
    render json: {token: current_user.authentication_token}
  end

  private

  def account_update_params
    params.permit(:email, :preferred_language)
  end

  def account_json(user)
    {
      email: user.email,
      admin: user.admin?,
      otp_enabled: user.otp_enabled?,
      preferred_language: user.preferred_language,
      created_at: user.created_at.iso8601,
      token: user.authentication_token
    }
  end
end
