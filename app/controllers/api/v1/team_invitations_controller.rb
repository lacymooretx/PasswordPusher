# frozen_string_literal: true

# JSON API for managing team invitations. Token-authenticated via Api::BaseController.
# Requires Settings.enable_teams. Any team member can list pending invitations;
# admins/owners can create or revoke invitations.
class Api::V1::TeamInvitationsController < Api::BaseController
  before_action :check_feature_enabled
  before_action :set_team, except: [:accept]
  before_action :require_admin, only: [:create, :destroy]

  resource_description do
    name "Team Invitations"
    short "Manage team invitations."
  end

  api :GET, "/api/v1/teams/:team_slug/invitations.json", "List pending invitations."
  param :team_slug, String, desc: "The slug of the team.", required: true
  formats ["JSON"]
  description <<-EOS
    Returns all pending invitations for the specified team, ordered by most recent.
    Any team member can view pending invitations.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Team not found or teams feature is not enabled."
  def index
    invitations = @team.team_invitations.pending.order(created_at: :desc)
    render json: invitations.map { |i| invitation_json(i) }
  end

  api :POST, "/api/v1/teams/:team_slug/invitations.json", "Send an invitation."
  param :team_slug, String, desc: "The slug of the team.", required: true
  param :email, String, desc: "Email address of the person to invite.", required: true
  param :role, %w[member admin], desc: "Role for the invitee. Defaults to 'member'."
  formats ["JSON"]
  description <<-EOS
    Sends an invitation to join the team. Only team admins and owners can
    send invitations. The invitee will receive an email with instructions.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - you must be a team admin."
  error code: 404, desc: "Team not found or teams feature is not enabled."
  error code: 422, desc: "Validation failed (e.g. duplicate invitation, invalid email)."
  def create
    invitation = @team.team_invitations.build(
      email: params[:email],
      role: params[:role] || :member,
      invited_by: current_user
    )

    if invitation.save
      render json: invitation_json(invitation), status: :created
    else
      render json: {errors: invitation.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :DELETE, "/api/v1/teams/:team_slug/invitations/:id.json", "Revoke an invitation."
  param :team_slug, String, desc: "The slug of the team.", required: true
  param :id, Integer, desc: "The ID of the invitation to revoke.", required: true
  formats ["JSON"]
  description <<-EOS
    Revokes a pending invitation. Only team admins and owners can revoke
    invitations. The invitation link will no longer be valid.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - you must be a team admin."
  error code: 404, desc: "Team or invitation not found."
  def destroy
    invitation = @team.team_invitations.find(params[:id])
    invitation.destroy
    head :no_content
  end

  api :POST, "/api/v1/teams/invitations/:token/accept.json", "Accept a team invitation."
  param :token, String, desc: "The invitation token.", required: true
  formats ["JSON"]
  description <<-EOS
    Accepts a team invitation using the invitation token. The authenticated
    user will be added to the team with the role specified in the invitation.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Invitation not found or teams feature not enabled."
  error code: 422, desc: "Already a team member, invitation expired, or already accepted."
  def accept
    invitation = TeamInvitation.find_by(token: params[:token])

    unless invitation
      render json: {error: "Invitation not found"}, status: :not_found
      return
    end

    if invitation.expired?
      render json: {error: "Invitation has expired"}, status: :unprocessable_content
      return
    end

    if invitation.accepted?
      render json: {error: "Invitation has already been accepted"}, status: :unprocessable_content
      return
    end

    if invitation.team.member?(current_user)
      render json: {error: "You are already a member of this team"}, status: :unprocessable_content
      return
    end

    if invitation.accept!(current_user)
      render json: {
        message: "Invitation accepted",
        team: {slug: invitation.team.slug, name: invitation.team.name},
        role: invitation.role
      }
    else
      render json: {error: "Failed to accept invitation"}, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
      render json: {error: "Teams feature is not enabled"}, status: :not_found
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

  def invitation_json(invitation)
    {
      id: invitation.id,
      email: invitation.email,
      role: invitation.role,
      expires_at: invitation.expires_at.iso8601,
      created_at: invitation.created_at.iso8601
    }
  end
end
