# frozen_string_literal: true

# Settings page for per-team branding customization (logo, colors, text).
# Builds or finds the team's TeamBranding record. Requires both
# Settings.enable_teams and Settings.enable_user_branding.
class TeamBrandingsController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled
  before_action :set_team
  before_action :require_team_admin

  layout "team_settings"

  ALLOWED_TABS = %w[assets retrieval passphrase delivery request_delivery request_ready expired].freeze

  def edit
    @team_branding = @team.team_branding || @team.build_team_branding
    @current_tab = ALLOWED_TABS.include?(params[:tab]) ? params[:tab] : "assets"
  end

  def update
    @team_branding = @team.team_branding || @team.build_team_branding
    @team_branding.assign_attributes(team_branding_params)

    if @team_branding.save
      redirect_to edit_team_branding_path(@team), notice: I18n._("Team branding settings have been saved.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_teams) && Settings.enable_teams &&
        Settings.respond_to?(:enable_user_branding) && Settings.enable_user_branding
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

  def team_branding_params
    params.require(:team_branding).permit(
      :delivery_heading, :delivery_message, :delivery_footer,
      :white_label, :brand_title, :brand_tagline,
      :primary_color, :background_color, :logo,
      :retrieval_heading, :retrieval_message, :retrieval_footer,
      :passphrase_heading, :passphrase_message,
      :request_delivery_heading, :request_delivery_message,
      :request_ready_message, :expired_message
    )
  end
end
