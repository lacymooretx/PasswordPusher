# frozen_string_literal: true

require "test_helper"

class TeamInvitationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @team = teams(:one_team)
    Settings.enable_teams = true
  end

  teardown do
    Settings.enable_teams = false
  end

  test "create sends invitation" do
    sign_in @user
    assert_difference "TeamInvitation.count", 1 do
      post team_invitations_path(@team), params: {
        team_invitation: { email: "invite@example.com", role: "member" }
      }
    end
    assert_response :redirect
  end

  test "create fails with invalid email" do
    sign_in @user
    assert_no_difference "TeamInvitation.count" do
      post team_invitations_path(@team), params: {
        team_invitation: { email: "", role: "member" }
      }
    end
    assert_response :redirect
  end

  test "destroy revokes invitation" do
    sign_in @user
    invitation = team_invitations(:pending_invitation)
    assert_difference "TeamInvitation.count", -1 do
      delete team_invitation_path(@team, invitation)
    end
    assert_response :redirect
  end

  test "accept works for logged in user" do
    sign_in users(:luca) # not a member
    invitation = team_invitations(:pending_invitation)
    get accept_team_invitation_path(token: invitation.token)
    assert_response :redirect
    assert @team.member?(users(:luca))
  end

  test "accept redirects to login for anonymous" do
    invitation = team_invitations(:pending_invitation)
    get accept_team_invitation_path(token: invitation.token)
    assert_response :redirect
  end

  test "accept fails for expired invitation" do
    sign_in users(:luca)
    invitation = team_invitations(:expired_invitation)
    get accept_team_invitation_path(token: invitation.token)
    assert_response :redirect
    assert_not @team.member?(users(:luca))
  end

  test "accept shows notice for existing member" do
    sign_in @user # already a member
    invitation = team_invitations(:pending_invitation)
    get accept_team_invitation_path(token: invitation.token)
    assert_response :redirect
  end
end
