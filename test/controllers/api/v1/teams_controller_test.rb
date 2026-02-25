# frozen_string_literal: true

require "test_helper"

class Api::V1::TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_teams = true
    @user = users(:one)
    sign_in @user
  end

  teardown do
    Settings.enable_teams = false
  end

  test "index returns user teams" do
    get api_v1_teams_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |t| t["slug"] == "acme-corp" }
  end

  test "show returns team details" do
    get api_v1_team_path("acme-corp", format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Acme Corp", json["name"]
    assert_equal "acme-corp", json["slug"]
    assert_equal @user.email, json.dig("owner", "email")
  end

  test "create team" do
    assert_difference("Team.count", 1) do
      post api_v1_teams_path(format: :json), params: {team: {name: "New API Team"}}
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New API Team", json["name"]
  end

  test "update team" do
    patch api_v1_team_path("acme-corp", format: :json), params: {team: {description: "Updated desc"}}
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated desc", json["description"]
  end

  test "destroy team as owner" do
    assert_difference("Team.count", -1) do
      delete api_v1_team_path("acme-corp", format: :json)
    end
    assert_response :no_content
  end

  test "destroy team as non-owner forbidden" do
    sign_in users(:giuliana)
    delete api_v1_team_path("acme-corp", format: :json)
    assert_response :forbidden
  end

  test "feature disabled returns not found" do
    Settings.enable_teams = false
    get api_v1_teams_path(format: :json)
    assert_response :not_found
  end

  test "show team not found returns 404" do
    get api_v1_team_path("nonexistent-slug", format: :json)
    assert_response :not_found
  end

  test "create team with invalid data returns errors" do
    post api_v1_teams_path(format: :json), params: {team: {name: ""}}
    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert json["errors"].any?
  end
end
