# frozen_string_literal: true

# Mailer for team-related notifications: invitation emails, new member
# confirmations (sent to owner), and 2FA reminder emails.
class TeamMailer < ApplicationMailer
  # Sends an invitation link to the invitee's email address.
  def invitation_email(invitation)
    @invitation = invitation
    @team = invitation.team
    @accept_url = accept_team_invitation_url(token: invitation.token)

    mail(
      to: invitation.email,
      subject: I18n._("You've been invited to join %{team}") % {team: @team.name}
    )
  end

  # Notifies the team owner that a new member has joined.
  def member_added(team, user)
    @team = team
    @user = user

    mail(
      to: team.owner.email,
      subject: I18n._("%{email} has joined %{team}") % {email: user.email, team: team.name}
    )
  end

  # Reminds a team member to enable 2FA when the team requires it.
  def two_factor_reminder(team, user)
    @team = team
    @user = user

    mail(
      to: user.email,
      subject: I18n._("Action required: Enable two-factor authentication for %{team}") % {team: team.name}
    )
  end
end
