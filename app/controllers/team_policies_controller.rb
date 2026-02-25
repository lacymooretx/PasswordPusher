# frozen_string_literal: true

# Team admin interface for configuring push policies. The policy is stored as
# a JSON column on Team with four top-level keys: "defaults" (per-kind default
# values), "forced" (locked settings members cannot override), "hidden_features"
# (push kinds hidden from team members), and "limits" (max values per kind).
class TeamPoliciesController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled
  before_action :set_team
  before_action :require_team_member, only: [:show]
  before_action :require_team_admin, only: [:edit, :update]

  layout "team_settings"

  def show
    @policy = @team.policy || {}
  end

  def edit
    @policy = @team.policy || {}
  end

  def update
    @team.policy = build_policy_from_params
    if @team.save
      redirect_to team_path(@team), notice: I18n._("Team policy updated successfully.")
    else
      @policy = @team.policy
      render :edit, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
      redirect_to root_path, notice: I18n._("This feature is not enabled.")
    end
  end

  def set_team
    @team = current_user.teams.find_by!(slug: params[:team_id])
  end

  def require_team_member
    unless @team.member?(current_user)
      redirect_to teams_path, alert: I18n._("You don't have permission to do that.")
    end
  end

  def require_team_admin
    unless @team.admin?(current_user)
      redirect_to @team, alert: I18n._("You don't have permission to do that.")
    end
  end

  PUSH_KINDS = %w[pw url file qr].freeze
  SETTING_ATTRS = %w[expire_after_days expire_after_views].freeze
  BOOL_ATTRS = %w[retrieval_step deletable_pushes].freeze
  HIDDEN_FEATURES = %w[url_pushes file_pushes qr_pushes].freeze

  # Constructs the policy JSON hash from nested form params. Iterates over
  # each push kind and setting type, casting values appropriately (integers
  # for numeric settings, booleans for toggles, "1" checks for forced flags).
  def build_policy_from_params
    policy = {}
    policy_params = params[:policy] || {}

    # Defaults
    defaults = {}
    PUSH_KINDS.each do |kind|
      kind_defaults = {}
      kind_params = policy_params.dig(:defaults, kind) || {}

      SETTING_ATTRS.each do |attr|
        val = kind_params[attr]
        kind_defaults[attr] = val.to_i if val.present?
      end

      BOOL_ATTRS.each do |attr|
        val = kind_params[attr]
        kind_defaults[attr] = ActiveModel::Type::Boolean.new.cast(val) unless val.nil?
      end

      defaults[kind] = kind_defaults if kind_defaults.any?
    end
    policy["defaults"] = defaults if defaults.any?

    # Forced settings
    forced = {}
    PUSH_KINDS.each do |kind|
      kind_forced = {}
      forced_params = policy_params.dig(:forced, kind) || {}

      (SETTING_ATTRS + BOOL_ATTRS).each do |attr|
        kind_forced[attr] = true if forced_params[attr] == "1"
      end

      forced[kind] = kind_forced if kind_forced.any?
    end
    policy["forced"] = forced if forced.any?

    # Hidden features
    hidden = {}
    hidden_params = policy_params[:hidden_features] || {}
    HIDDEN_FEATURES.each do |feature|
      hidden[feature] = true if hidden_params[feature] == "1"
    end
    policy["hidden_features"] = hidden if hidden.any?

    # Limits
    limits = {}
    PUSH_KINDS.each do |kind|
      kind_limits = {}
      limit_params = policy_params.dig(:limits, kind) || {}

      %w[expire_after_days_max expire_after_views_max].each do |attr|
        val = limit_params[attr]
        kind_limits[attr] = val.to_i if val.present?
      end

      limits[kind] = kind_limits if kind_limits.any?
    end
    policy["limits"] = limits if limits.any?

    policy
  end
end
