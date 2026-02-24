# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  layout "login"

  # POST /resource/sign_in
  def create
    if two_factor_enabled?
      user = self.resource = warden.authenticate!(auth_options.merge(store: false))
      if user.otp_enabled?
        # Store user ID in session for OTP verification step
        session[:otp_user_id] = user.id
        session[:otp_remember_me] = sign_in_params[:remember_me]
        sign_out(user) # Don't fully sign in yet
        redirect_to new_users_two_factor_verification_path
        return
      end
    end

    # Normal sign-in flow (no 2FA or 2FA not enabled for this user)
    super
  end

  # after_sign_out_path_for
  #
  # This method is called after the user has signed out.
  # Ensure the session data is cleared and the session cookie is deleted.
  #
  def after_sign_out_path_for(resource_or_scope)
    reset_session  # Explicitly clear the session data
    cookies.delete("_PasswordPusher_session") # Delete the session cookie
    root_path      # Redirect to the root path after logout
  end

  private

  def two_factor_enabled?
    Settings.respond_to?(:enable_two_factor) && Settings.enable_two_factor
  end
end
