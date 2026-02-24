# frozen_string_literal: true

class TeamsController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled
  before_action :set_team, only: %i[show edit update destroy]
  before_action :require_team_admin, only: %i[edit update destroy]

  def index
    @teams = current_user.teams.order(:name)
  end

  def show
    @memberships = @team.memberships.includes(:user).order(:role, :created_at)
    @pending_invitations = @team.team_invitations.pending if @team.admin?(current_user)
    @pushes = @team.pushes.order(created_at: :desc).page(params[:page])
  end

  def new
    @team = Team.new
  end

  def create
    @team = Team.new(team_params)
    @team.owner = current_user

    if @team.save
      redirect_to @team, notice: I18n._("Team created successfully.")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @team.update(team_params)
      redirect_to @team, notice: I18n._("Team updated successfully.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    return redirect_to @team, alert: I18n._("Only the team owner can delete the team.") unless @team.owner?(current_user)

    @team.destroy
    redirect_to teams_path, notice: I18n._("Team deleted.")
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
      redirect_to root_path, notice: I18n._("This feature is not enabled.")
    end
  end

  def set_team
    @team = current_user.teams.find_by!(slug: params[:id])
  end

  def require_team_admin
    unless @team.admin?(current_user)
      redirect_to @team, alert: I18n._("You don't have permission to do that.")
    end
  end

  def team_params
    params.require(:team).permit(:name, :description)
  end
end
