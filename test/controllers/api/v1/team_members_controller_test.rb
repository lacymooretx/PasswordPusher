# frozen_string_literal: true

require "test_helper"

class Api::V1::TeamMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_teams = true
    @user = users(:one)
    sign_in @user
  end

  teardown do
    Settings.enable_teams = false
  end

  test "index returns members" do
    get api_v1_team_members_path("acme-corp", format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.length >= 2
  end

  test "create adds member by email" do
    assert_difference("Membership.count", 1) do
      post api_v1_team_members_path("acme-corp", format: :json), params: {email: "luca@example.org"}
    end
    assert_response :created
  end

  test "create with unknown email returns not found" do
    post api_v1_team_members_path("acme-corp", format: :json), params: {email: "nonexistent@example.org"}
    assert_response :not_found
  end

  test "create with already existing member returns unprocessable" do
    post api_v1_team_members_path("acme-corp", format: :json), params: {email: "giuliana@example.org"}
    assert_response :unprocessable_content
  end

  test "destroy removes member" do
    membership = memberships(:admin_membership)
    assert_difference("Membership.count", -1) do
      delete api_v1_team_member_path("acme-corp", membership.id, format: :json)
    end
    assert_response :no_content
  end

  # --- update role ---

  test "update member role" do
    membership = memberships(:admin_membership)
    patch api_v1_team_member_path("acme-corp", membership, format: :json), params: {role: "member"}
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "member", json["role"]
    membership.reload
    assert_equal "member", membership.role
  end

  test "cannot change owner role" do
    membership = memberships(:owner_membership)
    patch api_v1_team_member_path("acme-corp", membership, format: :json), params: {role: "admin"}
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_equal "Cannot change the owner's role", json["error"]
  end

  test "non-admin cannot update roles" do
    sign_in users(:luca)
    membership = memberships(:admin_membership)
    patch api_v1_team_member_path("acme-corp", membership, format: :json), params: {role: "member"}
    assert_response :not_found
  end

  test "feature disabled returns not found" do
    Settings.enable_teams = false
    get api_v1_team_members_path("acme-corp", format: :json)
    assert_response :not_found
  end

  test "team not found returns 404" do
    get api_v1_team_members_path("nonexistent-slug", format: :json)
    assert_response :not_found
  end
end
