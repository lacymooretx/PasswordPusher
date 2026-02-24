# frozen_string_literal: true

# Manages team membership roles and removal. Role changes require admin+
# privileges. Removal logic: owners can't be removed, admins can remove
# members, any member can leave (self-remove). The owner must transfer
# ownership or delete the team to leave.
class MembershipsController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled
  before_action :set_team
  before_action :require_team_admin, only: %i[update]
  before_action :set_membership, only: %i[update destroy]

  # PATCH /teams/:team_id/memberships/:id - Change role
  def update
    if @membership.owner?
      redirect_to @team, alert: I18n._("Cannot change the owner's role.")
      return
    end

    if @membership.update(membership_params)
      redirect_to @team, notice: I18n._("Role updated for %{email}.") % { email: @membership.user.email }
    else
      redirect_to @team, alert: @membership.errors.full_messages.join(", ")
    end
  end

  # DELETE /teams/:team_id/memberships/:id - Remove member or leave team
  # Handles two distinct flows: self-removal (leaving) and removing another
  # member. Permission checks differ for each case.
  def destroy
    current_membership = @team.membership_for(current_user)

    # Leaving the team
    if @membership.user == current_user
      if @membership.owner?
        redirect_to @team, alert: I18n._("The team owner cannot leave. Transfer ownership or delete the team.")
        return
      end
      @membership.destroy
      redirect_to teams_path, notice: I18n._("You have left the team.")
      return
    end

    # Removing someone else
    unless current_membership&.can_manage_members?
      redirect_to @team, alert: I18n._("You don't have permission to do that.")
      return
    end

    unless @membership.removable_by?(current_membership)
      redirect_to @team, alert: I18n._("You cannot remove this member.")
      return
    end

    email = @membership.user.email
    @membership.destroy
    redirect_to @team, notice: I18n._("%{email} has been removed from the team.") % { email: email }
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

  def require_team_admin
    unless @team.admin?(current_user)
      redirect_to @team, alert: I18n._("You don't have permission to do that.")
    end
  end

  def set_membership
    @membership = @team.memberships.find(params[:id])
  end

  def membership_params
    params.require(:membership).permit(:role)
  end
end
