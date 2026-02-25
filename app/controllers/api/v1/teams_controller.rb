# frozen_string_literal: true

# JSON API for managing teams. Token-authenticated via Api::BaseController.
# Requires Settings.enable_teams. Users can list/view their teams, create new
# teams, and (with admin+ role) update or destroy them.
class Api::V1::TeamsController < Api::BaseController
  before_action :check_feature_enabled
  before_action :set_team, only: [:show, :update, :destroy]
  before_action :require_admin, only: [:update, :destroy]

  resource_description do
    name "Teams"
    short "Manage teams and collaboration."
  end

  api :GET, "/api/v1/teams.json", "List your teams."
  formats ["JSON"]
  description <<-EOS
    Returns all teams the authenticated user belongs to, ordered by name.
    Requires authentication via API token.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Teams feature is not enabled."
  def index
    @teams = current_user.teams.order(:name)
    render json: @teams.map { |t| team_json(t) }
  end

  api :GET, "/api/v1/teams/:slug.json", "Get team details."
  param :slug, String, desc: "The unique slug identifier for the team.", required: true
  formats ["JSON"]
  description <<-EOS
    Retrieves detailed information about a specific team, including owner
    and settings. The authenticated user must be a member of the team.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Team not found or teams feature is not enabled."
  def show
    render json: team_json(@team, detail: true)
  end

  api :POST, "/api/v1/teams.json", "Create a team."
  param :team, Hash, desc: "Team attributes.", required: true do
    param :name, String, desc: "The display name for the team.", required: true
    param :slug, String, desc: "URL-friendly identifier. Must be unique."
    param :description, String, desc: "A short description of the team."
  end
  formats ["JSON"]
  description <<-EOS
    Creates a new team owned by the authenticated user. The slug is used
    as the unique URL identifier for the team.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Teams feature is not enabled."
  error code: 422, desc: "Validation failed (e.g. name blank, slug taken)."
  def create
    @team = Team.new(team_params)
    @team.owner = current_user

    if @team.save
      render json: team_json(@team), status: :created
    else
      render json: {errors: @team.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :PUT, "/api/v1/teams/:slug.json", "Update a team."
  param :slug, String, desc: "The unique slug identifier for the team.", required: true
  param :team, Hash, desc: "Team attributes to update.", required: true do
    param :name, String, desc: "The display name for the team."
    param :slug, String, desc: "URL-friendly identifier. Must be unique."
    param :description, String, desc: "A short description of the team."
  end
  formats ["JSON"]
  description <<-EOS
    Updates an existing team. Only team admins and owners can perform this action.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - you must be a team admin."
  error code: 404, desc: "Team not found or teams feature is not enabled."
  error code: 422, desc: "Validation failed."
  def update
    if @team.update(team_params)
      render json: team_json(@team)
    else
      render json: {errors: @team.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :DELETE, "/api/v1/teams/:slug.json", "Delete a team."
  param :slug, String, desc: "The unique slug identifier for the team.", required: true
  formats ["JSON"]
  description <<-EOS
    Permanently deletes a team. Only the team owner can perform this action.
    All memberships and invitations are removed.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - only the team owner can delete."
  error code: 404, desc: "Team not found or teams feature is not enabled."
  def destroy
    unless @team.owner?(current_user)
      render json: {error: "Only the owner can delete this team"}, status: :forbidden
      return
    end
    @team.destroy
    head :no_content
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
      render json: {error: "Teams feature is not enabled"}, status: :not_found
    end
  end

  def set_team
    @team = current_user.teams.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Team not found"}, status: :not_found
  end

  def require_admin
    unless @team.admin?(current_user)
      render json: {error: "You must be a team admin"}, status: :forbidden
    end
  end

  def team_params
    params.require(:team).permit(:name, :slug, :description)
  end

  def team_json(team, detail: false)
    json = {
      slug: team.slug,
      name: team.name,
      description: team.description,
      member_count: team.member_count,
      created_at: team.created_at.iso8601
    }
    if detail
      json[:owner] = {email: team.owner.email}
      json[:require_two_factor] = team.require_two_factor
    end
    json
  end
end
