# frozen_string_literal: true

# JSON API for managing team memberships. Token-authenticated via Api::BaseController.
# Requires Settings.enable_teams. Any team member can list members; admins/owners
# can add or remove members.
class Api::V1::TeamMembersController < Api::BaseController
  before_action :check_feature_enabled
  before_action :set_team
  before_action :require_admin, only: [:create, :update, :destroy]

  resource_description do
    name "Team Members"
    short "Manage team memberships."
  end

  api :GET, "/api/v1/teams/:team_slug/members.json", "List team members."
  param :team_slug, String, desc: "The slug of the team.", required: true
  formats ["JSON"]
  description <<-EOS
    Returns all members of the specified team with their roles and join dates.
    Any team member can list the membership roster.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Team not found or teams feature is not enabled."
  def index
    members = @team.memberships.includes(:user).order(:created_at)
    render json: members.map { |m| member_json(m) }
  end

  api :POST, "/api/v1/teams/:team_slug/members.json", "Add a team member."
  param :team_slug, String, desc: "The slug of the team.", required: true
  param :email, String, desc: "Email address of the user to add.", required: true
  param :role, %w[member admin], desc: "Role for the new member. Defaults to 'member'."
  formats ["JSON"]
  description <<-EOS
    Adds an existing user to the team by email address. Only team admins
    and owners can add members. The user must already have an account.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - you must be a team admin."
  error code: 404, desc: "User not found with that email, or team not found."
  error code: 422, desc: "User is already a member or validation failed."
  def create
    user = User.find_by(email: params[:email])
    unless user
      render json: {error: "User not found with that email"}, status: :not_found
      return
    end

    if @team.member?(user)
      render json: {error: "User is already a member"}, status: :unprocessable_content
      return
    end

    membership = @team.memberships.create(user: user, role: params[:role] || :member)
    if membership.persisted?
      render json: member_json(membership), status: :created
    else
      render json: {errors: membership.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :PATCH, "/api/v1/teams/:team_slug/members/:id.json", "Update a team member's role."
  param :team_slug, String, desc: "The slug of the team.", required: true
  param :id, Integer, desc: "The membership ID.", required: true
  param :role, %w[member admin], desc: "New role for the member.", required: true
  formats ["JSON"]
  description <<-EOS
    Updates a team member's role. Only team admins and owners can change roles.
    The owner role cannot be changed.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - you must be a team admin."
  error code: 404, desc: "Team or membership not found."
  error code: 422, desc: "Cannot change owner role."
  def update
    membership = @team.memberships.find(params[:id])

    if membership.owner?
      render json: {error: "Cannot change the owner's role"}, status: :unprocessable_content
      return
    end

    if membership.update(role: params[:role])
      render json: member_json(membership)
    else
      render json: {errors: membership.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :DELETE, "/api/v1/teams/:team_slug/members/:id.json", "Remove a team member."
  param :team_slug, String, desc: "The slug of the team.", required: true
  param :id, Integer, desc: "The membership ID of the member to remove.", required: true
  formats ["JSON"]
  description <<-EOS
    Removes a member from the team. Only admins and owners can remove members,
    subject to role hierarchy restrictions.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - cannot remove this member."
  error code: 404, desc: "Team or membership not found."
  def destroy
    membership = @team.memberships.find(params[:id])
    current_membership = @team.membership_for(current_user)

    unless membership.removable_by?(current_membership)
      render json: {error: "Cannot remove this member"}, status: :forbidden
      return
    end

    membership.destroy
    head :no_content
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

  def member_json(membership)
    {
      id: membership.id,
      email: membership.user.email,
      role: membership.role,
      joined_at: membership.created_at.iso8601
    }
  end
end
