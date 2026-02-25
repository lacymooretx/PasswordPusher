# frozen_string_literal: true

# Team admin 2FA compliance dashboard and enforcement toggle. Shows per-member
# 2FA status, overall compliance percentage, and allows toggling the
# require_two_factor flag. Can send reminder emails to non-compliant members.
# Requires both enable_teams and enable_two_factor Settings.
class TeamTwoFactorController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled
  before_action :set_team
  before_action :require_team_admin

  layout "team_settings"

  # GET /teams/:team_id/two_factor - Compliance dashboard
  def show
    @memberships = @team.memberships.includes(:user).order(:role, :created_at)
    @compliance_percentage = @team.two_factor_compliance_percentage
    @members_without_2fa = @team.members_without_2fa
  end

  # PATCH /teams/:team_id/two_factor - Toggle enforcement
  def update
    @team.update!(require_two_factor: params[:require_two_factor] == "1")
    redirect_to team_two_factor_path(@team),
      notice: @team.require_two_factor? ?
        I18n._("Two-factor authentication is now required for all team members.") :
        I18n._("Two-factor authentication requirement has been removed.")
  end

  # POST /teams/:team_id/two_factor/remind - Send reminder emails
  def remind
    non_compliant = @team.members_without_2fa.to_a
    non_compliant.each do |user|
      TeamMailer.two_factor_reminder(@team, user).deliver_later
    end
    redirect_to team_two_factor_path(@team),
      notice: I18n._("Reminder emails sent to %{count} members.") % {count: non_compliant.size}
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_teams) && Settings.enable_teams &&
        Settings.respond_to?(:enable_two_factor) && Settings.enable_two_factor
      redirect_to root_path, notice: I18n._("This feature is not enabled.")
    end
  end

  def set_team
    @team = current_user.teams.find_by!(slug: params[:team_id])
  end

  def require_team_admin
    unless @team.admin?(current_user)
      redirect_to @team, alert: I18n._("You don't have permission to do that.")
    end
  end
end
