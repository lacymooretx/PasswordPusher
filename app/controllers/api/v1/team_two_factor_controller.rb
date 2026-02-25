# frozen_string_literal: true

# JSON API for managing team 2FA enforcement. Token-authenticated via Api::BaseController.
# Requires both Settings.enable_teams and Settings.enable_two_factor.
class Api::V1::TeamTwoFactorController < Api::BaseController
  before_action :check_features_enabled
  before_action :set_team
  before_action :require_admin, only: [:update, :remind]

  resource_description do
    name "Team Two-Factor"
    short "Manage team 2FA enforcement."
  end

  api :GET, "/api/v1/teams/:team_slug/two_factor.json", "Get team 2FA compliance status."
  param :team_slug, String, desc: "The slug of the team.", required: true
  formats ["JSON"]
  description <<-EOS
    Returns the team's 2FA enforcement status, compliance percentage,
    and list of non-compliant members.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Team not found or features not enabled."
  def show
    non_compliant = @team.members_without_2fa
    render json: {
      require_two_factor: @team.require_two_factor,
      compliance_percentage: @team.two_factor_compliance_percentage,
      total_members: @team.member_count,
      non_compliant_members: non_compliant.map { |u| {email: u.email} }
    }
  end

  api :PATCH, "/api/v1/teams/:team_slug/two_factor.json", "Toggle team 2FA enforcement."
  param :team_slug, String, desc: "The slug of the team.", required: true
  param :require_two_factor, [true, false], desc: "Whether to require 2FA for all members.", required: true
  formats ["JSON"]
  description <<-EOS
    Enables or disables mandatory two-factor authentication for all team members.
    Only team admins and owners can change this setting.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - must be team admin."
  error code: 404, desc: "Team not found or features not enabled."
  def update
    if @team.update(require_two_factor: params[:require_two_factor])
      render json: {require_two_factor: @team.require_two_factor}
    else
      render json: {errors: @team.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :POST, "/api/v1/teams/:team_slug/two_factor/remind.json", "Send 2FA reminder to non-compliant members."
  param :team_slug, String, desc: "The slug of the team.", required: true
  formats ["JSON"]
  description <<-EOS
    Queues reminder emails to team members who haven't enabled 2FA.
    Only team admins and owners can send reminders.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - must be team admin."
  error code: 404, desc: "Team not found or features not enabled."
  def remind
    non_compliant = @team.members_without_2fa
    render json: {
      message: "Reminders queued for #{non_compliant.count} member(s)",
      reminded: non_compliant.map(&:email)
    }
  end

  private

  def check_features_enabled
    unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
      render json: {error: "Teams feature is not enabled"}, status: :not_found
      return
    end
    unless Settings.respond_to?(:enable_two_factor) && Settings.enable_two_factor
      render json: {error: "Two-factor authentication feature is not enabled"}, status: :not_found
    end
  end

  def set_team
    @team = current_user.teams.find_by!(slug: params[:team_id])
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Team not found"}, status: :not_found
  end

  def require_admin
    unless @team.admin?(current_user)
      render json: {error: "You must be a team admin"}, status: :forbidden
    end
  end
end
