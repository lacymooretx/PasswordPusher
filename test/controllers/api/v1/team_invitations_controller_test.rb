# frozen_string_literal: true

require "test_helper"

class Api::V1::TeamInvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_teams = true
    @user = users(:one)
    sign_in @user
  end

  teardown do
    Settings.enable_teams = false
  end

  test "index returns pending invitations" do
    get api_v1_team_invitations_path("acme-corp", format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end

  test "create invitation" do
    assert_difference("TeamInvitation.count", 1) do
      post api_v1_team_invitations_path("acme-corp", format: :json), params: {email: "invite@example.org"}
    end
    assert_response :created
  end

  test "destroy invitation" do
    invitation = team_invitations(:pending_invitation)
    assert_difference("TeamInvitation.count", -1) do
      delete api_v1_team_invitation_path("acme-corp", invitation.id, format: :json)
    end
    assert_response :no_content
  end

  test "create invitation with invalid email returns errors" do
    post api_v1_team_invitations_path("acme-corp", format: :json), params: {email: "invalid"}
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert json["errors"].any?
  end

  # --- accept invitation ---

  test "accept invitation" do
    sign_in users(:luca)
    invitation = team_invitations(:pending_invitation)
    post api_v1_accept_team_invitation_path(invitation.token, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Invitation accepted", json["message"]
    assert_equal "acme-corp", json["team"]["slug"]
  end

  test "accept expired invitation fails" do
    sign_in users(:luca)
    invitation = team_invitations(:expired_invitation)
    post api_v1_accept_team_invitation_path(invitation.token, format: :json)
    assert_response :unprocessable_content
  end

  test "accept invitation when already member fails" do
    invitation = team_invitations(:pending_invitation)
    post api_v1_accept_team_invitation_path(invitation.token, format: :json)
    assert_response :unprocessable_content
  end

  test "accept with invalid token returns 404" do
    sign_in users(:luca)
    post api_v1_accept_team_invitation_path("nonexistent_token", format: :json)
    assert_response :not_found
  end

  test "feature disabled returns not found" do
    Settings.enable_teams = false
    get api_v1_team_invitations_path("acme-corp", format: :json)
    assert_response :not_found
  end

  test "team not found returns 404" do
    get api_v1_team_invitations_path("nonexistent-slug", format: :json)
    assert_response :not_found
  end
end
