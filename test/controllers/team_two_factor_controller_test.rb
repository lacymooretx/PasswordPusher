# frozen_string_literal: true

require "test_helper"

class TeamTwoFactorControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @team = teams(:one_team)
    Settings.enable_teams = true
    Settings.enable_two_factor = true
  end

  teardown do
    Settings.enable_teams = false
    Settings.enable_two_factor = false
  end

  test "show displays compliance dashboard" do
    sign_in @user
    get team_two_factor_path(@team)
    assert_response :success
  end

  test "show requires team admin" do
    member = users(:luca)
    @team.memberships.create!(user: member, role: :member)

    sign_in member
    get team_two_factor_path(@team)
    assert_response :redirect
  end

  test "update enables enforcement" do
    sign_in @user
    patch team_two_factor_path(@team), params: {require_two_factor: "1"}
    assert_response :redirect
    assert @team.reload.require_two_factor?
  end

  test "update disables enforcement" do
    @team.update!(require_two_factor: true)
    sign_in @user
    patch team_two_factor_path(@team), params: {require_two_factor: "0"}
    assert_response :redirect
    assert_not @team.reload.require_two_factor?
  end

  test "remind sends emails" do
    sign_in @user
    post remind_team_two_factor_path(@team)
    assert_response :redirect
  end

  test "redirects when teams disabled" do
    Settings.enable_teams = false
    sign_in @user
    get team_two_factor_path(@team)
    assert_response :redirect
  end

  test "redirects when 2fa disabled" do
    Settings.enable_two_factor = false
    sign_in @user
    get team_two_factor_path(@team)
    assert_response :redirect
  end
end
