# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/team_mailer
class TeamMailerPreview < ActionMailer::Preview
  def invitation_email
    invitation = TeamInvitation.first || TeamInvitation.new(
      email: "invitee@example.com",
      token: "preview_token_123",
      team: Team.first || Team.new(name: "Preview Team", slug: "preview-team"),
      expires_at: 7.days.from_now
    )
    TeamMailer.invitation_email(invitation)
  end

  def member_added
    team = Team.first || Team.new(name: "Preview Team", slug: "preview-team", owner: User.first)
    user = User.where.not(id: team.owner_id).first || User.first
    TeamMailer.member_added(team, user)
  end

  def two_factor_reminder
    team = Team.first || Team.new(name: "Preview Team", slug: "preview-team")
    user = User.first || User.new(email: "member@example.com")
    TeamMailer.two_factor_reminder(team, user)
  end
end
