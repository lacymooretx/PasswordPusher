# frozen_string_literal: true

require "test_helper"

class TeamTwoFactorEnforcementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @team = teams(:one_team)
    Settings.enable_teams = true
    Settings.enable_two_factor = true
    Settings.enable_logins = true
  end

  teardown do
    Settings.enable_teams = false
    Settings.enable_two_factor = false
    Settings.enable_logins = false
    @user.update!(otp_required_for_login: false, otp_secret: nil)
    @team.update!(require_two_factor: false)
  end

  test "redirects to 2fa setup when team requires it" do
    @team.update!(require_two_factor: true)
    sign_in @user

    get pushes_path
    assert_response :redirect
    assert_match(/two_factor/, response.location)
  end

  test "allows access when user has 2fa enabled" do
    @team.update!(require_two_factor: true)
    @user.update!(otp_required_for_login: true, otp_secret: ROTP::Base32.random)
    sign_in @user

    get pushes_path
    assert_response :success
  end

  test "allows access when no team requires 2fa" do
    sign_in @user
    get pushes_path
    assert_response :success
  end

  test "allows access when features disabled" do
    Settings.enable_teams = false
    @team.update!(require_two_factor: true)
    sign_in @user

    get pushes_path
    assert_response :success
  end
end
