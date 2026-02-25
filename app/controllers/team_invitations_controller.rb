# frozen_string_literal: true

# Manages team invitations: create (admin sends email), destroy (admin revokes),
# and accept (public token-based endpoint). The accept action handles edge cases
# like expired/used tokens, unauthenticated users (stores token in session for
# post-login redirect), and existing members.
class TeamInvitationsController < BaseController
  before_action :check_feature_enabled
  before_action :set_team, except: [:accept]
  before_action :require_team_admin, except: [:accept]

  # POST /teams/:team_id/invitations - Send invitation
  def create
    @invitation = @team.team_invitations.build(invitation_params)
    @invitation.invited_by = current_user

    if @invitation.save
      TeamMailer.invitation_email(@invitation).deliver_later
      redirect_to @team, notice: I18n._("Invitation sent to %{email}.") % {email: @invitation.email}
    else
      redirect_to @team, alert: @invitation.errors.full_messages.join(", ")
    end
  end

  # DELETE /teams/:team_id/invitations/:id - Revoke invitation
  def destroy
    invitation = @team.team_invitations.find(params[:id])
    invitation.destroy
    redirect_to @team, notice: I18n._("Invitation revoked.")
  end

  # GET /invitations/:token/accept - Accept invitation (public, requires login)
  def accept
    @invitation = TeamInvitation.find_by(token: params[:token])

    if @invitation.nil?
      redirect_to root_path, alert: I18n._("Invitation not found.")
      return
    end

    if @invitation.expired?
      redirect_to root_path, alert: I18n._("This invitation has expired.")
      return
    end

    if @invitation.accepted?
      redirect_to root_path, notice: I18n._("This invitation has already been accepted.")
      return
    end

    unless current_user
      # Store the token for after login
      session[:pending_invitation_token] = params[:token]
      redirect_to new_user_session_path, notice: I18n._("Please log in to accept the team invitation.")
      return
    end

    if @invitation.team.member?(current_user)
      redirect_to team_path(@invitation.team), notice: I18n._("You are already a member of this team.")
      return
    end

    if @invitation.accept!(current_user)
      TeamMailer.member_added(@invitation.team, current_user).deliver_later
      redirect_to team_path(@invitation.team), notice: I18n._("You have joined %{team}.") % {team: @invitation.team.name}
    else
      redirect_to root_path, alert: I18n._("Unable to accept invitation.")
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_teams) && Settings.enable_teams
      redirect_to root_path, notice: I18n._("This feature is not enabled.")
    end
  end

  def set_team
    authenticate_user!
    @team = current_user.teams.find_by!(slug: params[:team_id])
  end

  def require_team_admin
    unless @team.admin?(current_user)
      redirect_to @team, alert: I18n._("You don't have permission to do that.")
    end
  end

  def invitation_params
    params.require(:team_invitation).permit(:email, :role)
  end
end
