# frozen_string_literal: true

# Before-action concern included in BaseController that redirects users to
# the 2FA setup page when any of their teams requires two-factor authentication
# and they haven't enabled it yet. Exempts 2FA setup paths and logout to avoid
# redirect loops. Requires both enable_teams and enable_two_factor Settings.
module TeamTwoFactorEnforcement
  extend ActiveSupport::Concern

  included do
    before_action :check_team_2fa_requirement
  end

  private

  def check_team_2fa_requirement
    return unless current_user
    return unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
    return unless Settings.respond_to?(:enable_two_factor) && Settings.enable_two_factor
    return if current_user.otp_enabled?

    # Check if any of the user's teams require 2FA
    requiring_team = current_user.teams.find_by(require_two_factor: true)
    return unless requiring_team

    # Allow access to 2FA setup pages and logout
    return if two_factor_setup_path?

    redirect_to setup_users_two_factor_path,
      alert: I18n._("Your team '%{team}' requires two-factor authentication. Please set it up to continue.") % {team: requiring_team.name}
  end

  # Exemption list: paths that must remain accessible during enforcement
  # to allow users to actually set up 2FA and to sign out.
  def two_factor_setup_path?
    request.path.start_with?("/users/two_factor") ||
      request.path.match?(%r{/teams/.+/two_factor}) ||
      request.path == destroy_user_session_path
  end
end
