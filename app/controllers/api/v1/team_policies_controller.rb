# frozen_string_literal: true

# JSON API for viewing and updating team push policies. Token-authenticated
# via Api::BaseController. Requires Settings.enable_teams. Only team admins
# and owners can view or modify the policy.
class Api::V1::TeamPoliciesController < Api::BaseController
  before_action :check_feature_enabled
  before_action :set_team
  before_action :require_team_admin

  resource_description do
    name "Team Policies"
    short "View and manage team push policies."
  end

  api :GET, "/api/v1/teams/:team_id/policy.json", "Get the team push policy."
  param :team_id, String, desc: "The team slug.", required: true
  formats ["JSON"]
  description <<-EOS
    Returns the full push policy for a team, including defaults, forced settings,
    hidden features, and limits per push kind. Only team admins and owners can
    access this endpoint.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - you must be a team admin."
  error code: 404, desc: "Team not found or teams feature is not enabled."
  def show
    render json: {
      team_slug: @team.slug,
      team_name: @team.name,
      policy: @team.policy || {}
    }
  end

  api :PUT, "/api/v1/teams/:team_id/policy.json", "Update the team push policy."
  param :team_id, String, desc: "The team slug.", required: true
  param :policy, Hash, desc: "The policy JSON hash.", required: true do
    param :defaults, Hash, desc: "Default values per push kind (pw, url, file, qr)."
    param :forced, Hash, desc: "Forced (locked) settings per push kind."
    param :hidden_features, Hash, desc: "Features hidden from team members."
    param :limits, Hash, desc: "Maximum values per push kind."
  end
  formats ["JSON"]
  description <<-EOS
    Replaces the team push policy with the provided JSON hash. The policy
    controls defaults, forced settings, hidden features, and limits for
    each push kind. Only team admins and owners can update the policy.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 403, desc: "Forbidden - you must be a team admin."
  error code: 404, desc: "Team not found or teams feature is not enabled."
  error code: 422, desc: "Validation failed."
  def update
    @team.policy = policy_params
    if @team.save
      render json: {
        team_slug: @team.slug,
        team_name: @team.name,
        policy: @team.policy
      }
    else
      render json: {errors: @team.errors.full_messages}, status: :unprocessable_content
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

  def require_team_admin
    return if @team.nil? # already rendered not_found
    unless @team.admin?(current_user)
      render json: {error: "You must be a team admin"}, status: :forbidden
    end
  end

  def policy_params
    # Policy is a flexible JSON structure with nested keys per push kind.
    # We parse the raw JSON body to avoid permit! while still accepting
    # the nested hash structure.
    raw = params[:policy]
    return {} unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    raw.to_unsafe_h.deep_symbolize_keys.slice(:defaults, :forced, :hidden_features, :limits).deep_stringify_keys
  end
end
