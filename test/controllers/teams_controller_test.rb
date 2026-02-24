# frozen_string_literal: true

require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @team = teams(:one_team)
    Settings.enable_teams = true
  end

  teardown do
    Settings.enable_teams = false
  end

  test "index requires authentication" do
    get teams_path
    assert_response :redirect
  end

  test "index shows teams" do
    sign_in @user
    get teams_path
    assert_response :success
  end

  test "new shows form" do
    sign_in @user
    get new_team_path
    assert_response :success
  end

  test "create makes new team" do
    sign_in @user
    assert_difference "Team.count", 1 do
      post teams_path, params: {
        team: { name: "New Test Team", description: "A test team" }
      }
    end
    assert_response :redirect
    team = Team.last
    assert_equal @user, team.owner
    assert team.member?(@user)
  end

  test "show displays team" do
    sign_in @user
    get team_path(@team)
    assert_response :success
  end

  test "edit shows form for admin" do
    sign_in @user
    get edit_team_path(@team)
    assert_response :success
  end

  test "edit redirects non-admin" do
    sign_in users(:giuliana) # admin, so should work
    get edit_team_path(@team)
    assert_response :success
  end

  test "update changes team" do
    sign_in @user
    patch team_path(@team), params: {
      team: { name: "Updated Name" }
    }
    assert_response :redirect
    assert_equal "Updated Name", @team.reload.name
  end

  test "destroy deletes team for owner" do
    sign_in @user
    assert_difference "Team.count", -1 do
      delete team_path(@team)
    end
    assert_response :redirect
  end

  test "destroy redirects non-owner" do
    sign_in users(:giuliana) # admin but not owner
    delete team_path(@team)
    assert_response :redirect
    assert Team.exists?(@team.id) # team still exists
  end

  test "redirects when feature disabled" do
    Settings.enable_teams = false
    sign_in @user
    get teams_path
    assert_response :redirect
  end
end
