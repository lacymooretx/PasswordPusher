# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  layout "login", only: %i[link_account confirm_link]

  # Google OAuth2 callback
  def google_oauth2
    handle_omniauth("Google")
  end

  # Microsoft Graph callback
  def microsoft_graph
    handle_omniauth("Microsoft")
  end

  # GET /users/sso/link — show password verification form for account linking
  def link_account
    unless session[:pending_sso_link]
      redirect_to new_user_session_path, alert: I18n._("No pending SSO link request.")
      return
    end

    @sso_provider = session[:pending_sso_link]["provider_name"]
    @sso_email = session[:pending_sso_link]["email"]
  end

  # POST /users/sso/link — verify password and complete SSO linking
  def confirm_link
    pending = session[:pending_sso_link]
    unless pending
      redirect_to new_user_session_path, alert: I18n._("No pending SSO link request.")
      return
    end

    user = User.find_by(email: pending["email"])
    unless user
      session.delete(:pending_sso_link)
      redirect_to new_user_session_path, alert: I18n._("Account not found.")
      return
    end

    if user.valid_password?(params[:password])
      # Password verified — link the SSO identity
      user.link_omniauth!(
        provider: pending["provider"],
        uid: pending["uid"],
        avatar_url: pending["avatar_url"]
      )
      session.delete(:pending_sso_link)
      flash[:notice] = I18n._("Your %{provider} account has been linked successfully.") % {provider: pending["provider_name"]}
      sign_in_and_redirect user, event: :authentication
    else
      flash.now[:alert] = I18n._("Incorrect password. Please try again.")
      @sso_provider = pending["provider_name"]
      @sso_email = pending["email"]
      render :link_account, status: :unprocessable_content
    end
  end

  # Handle OmniAuth failure (invalid credentials, cancelled, etc.)
  def failure
    redirect_to root_path, alert: I18n._("SSO authentication failed. Please try again.")
  end

  private

  def handle_omniauth(provider_name)
    auth = request.env["omniauth.auth"]

    # Multi-tenant SSO: validate the user's tenant against the allowlist
    if ENV["PWP__SSO__MICROSOFT__MULTI_TENANT"] == "true" && provider_name == "Microsoft"
      user_tenant_id = auth.extra&.raw_info&.tid
      if user_tenant_id.present?
        # Always allow the app owner's tenant (from SSO config or partner tenant)
        owner_tenant = ENV["PWP__SSO__MICROSOFT__TENANT_ID"] || ENV["AZURE_PARTNER_TENANT_ID"]
        unless user_tenant_id == owner_tenant ||
               (defined?(CspTenant) && CspTenant.exists?(tenant_id: user_tenant_id, sso_enabled: true))
          flash[:alert] = I18n._("Your organization is not authorized to sign in. Please contact your administrator.")
          redirect_to new_user_session_path
          return
        end
      end
    end

    result = User.from_omniauth(auth)

    case result.status
    when :found, :created
      flash[:notice] = I18n._("Successfully signed in with %{provider}.") % {provider: provider_name}
      sign_in_and_redirect result.user, event: :authentication
    when :conflict
      # Email matches existing account — require password verification
      session[:pending_sso_link] = {
        "provider" => auth.provider,
        "uid" => auth.uid,
        "email" => auth.info.email,
        "avatar_url" => auth.info.image,
        "provider_name" => provider_name
      }
      redirect_to sso_link_path, notice: I18n._("An account with this email already exists. Please enter your password to link your %{provider} account.") % {provider: provider_name}
    else
      flash[:alert] = I18n._("Could not sign in with %{provider}. Please try again.") % {provider: provider_name}
      redirect_to new_user_session_path
    end
  end
end
