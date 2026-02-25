# frozen_string_literal: true

require "test_helper"

class TeamMailerTest < ActionMailer::TestCase
  setup do
    # invitation_email generates an accept URL that requires a host
    @original_options = ActionMailer::Base.default_url_options.dup
    ActionMailer::Base.default_url_options[:host] = "localhost"
  end

  teardown do
    ActionMailer::Base.default_url_options = @original_options
  end

  # --- invitation_email ---

  test "invitation_email sends email" do
    invitation = team_invitations(:pending_invitation)

    assert_emails 1 do
      TeamMailer.invitation_email(invitation).deliver_now
    end
  end

  test "invitation_email is addressed to invitee" do
    invitation = team_invitations(:pending_invitation)

    email = TeamMailer.invitation_email(invitation)
    assert_equal [invitation.email], email.to
  end

  test "invitation_email subject includes team name" do
    invitation = team_invitations(:pending_invitation)

    email = TeamMailer.invitation_email(invitation)
    assert_includes email.subject, invitation.team.name
  end

  # --- member_added ---

  test "member_added sends email" do
    team = teams(:one_team)
    user = users(:giuliana)

    assert_emails 1 do
      TeamMailer.member_added(team, user).deliver_now
    end
  end

  test "member_added is addressed to team owner" do
    team = teams(:one_team)
    user = users(:giuliana)

    email = TeamMailer.member_added(team, user)
    assert_equal [team.owner.email], email.to
  end

  test "member_added subject includes user email and team name" do
    team = teams(:one_team)
    user = users(:giuliana)

    email = TeamMailer.member_added(team, user)
    assert_includes email.subject, user.email
    assert_includes email.subject, team.name
  end

  # --- two_factor_reminder ---

  test "two_factor_reminder sends email" do
    team = teams(:one_team)
    user = users(:giuliana)

    assert_emails 1 do
      TeamMailer.two_factor_reminder(team, user).deliver_now
    end
  end

  test "two_factor_reminder is addressed to user" do
    team = teams(:one_team)
    user = users(:giuliana)

    email = TeamMailer.two_factor_reminder(team, user)
    assert_equal [user.email], email.to
  end

  test "two_factor_reminder subject includes team name" do
    team = teams(:one_team)
    user = users(:giuliana)

    email = TeamMailer.two_factor_reminder(team, user)
    assert_includes email.subject, team.name
  end
end
