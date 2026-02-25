# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Google OAuth2 callback
  def google_oauth2
    handle_omniauth("Google")
  end

  # Microsoft Graph callback
  def microsoft_graph
    handle_omniauth("Microsoft")
  end

  # Handle OmniAuth failure (invalid credentials, cancelled, etc.)
  def failure
    redirect_to root_path, alert: I18n._("SSO authentication failed. Please try again.")
  end

  private

  def handle_omniauth(provider_name)
    auth = request.env["omniauth.auth"]

    @user = User.from_omniauth(auth)

    if @user.persisted?
      flash[:notice] = I18n._("Successfully signed in with %{provider}.") % {provider: provider_name}
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = I18n._("Could not sign in with %{provider}. Please try again.") % {provider: provider_name}
      redirect_to new_user_session_path
    end
  end
end
