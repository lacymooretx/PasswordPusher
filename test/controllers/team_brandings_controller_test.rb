# frozen_string_literal: true

require "test_helper"

class TeamBrandingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @team = teams(:one_team)
    Settings.enable_teams = true
    Settings.enable_user_branding = true
  end

  teardown do
    Settings.enable_teams = false
    Settings.enable_user_branding = false
  end

  test "edit renders branding form for admin" do
    sign_in @user
    get edit_team_branding_path(@team)
    assert_response :success
  end

  test "edit requires authentication" do
    get edit_team_branding_path(@team)
    assert_response :redirect
  end

  test "edit requires team admin" do
    member = users(:luca)
    @team.memberships.create!(user: member, role: :member)

    sign_in member
    get edit_team_branding_path(@team)
    assert_response :redirect
  end

  test "update saves branding settings" do
    sign_in @user
    patch team_branding_path(@team), params: {
      team_branding: {
        brand_title: "Acme Corp",
        brand_tagline: "Secure sharing",
        delivery_heading: "Secure message",
        white_label: "0"
      }
    }
    assert_response :redirect
    assert_redirected_to edit_team_branding_path(@team)
    branding = @team.reload.team_branding
    assert_equal "Acme Corp", branding.brand_title
    assert_equal "Secure sharing", branding.brand_tagline
  end

  test "update with invalid color shows errors" do
    sign_in @user
    patch team_branding_path(@team), params: {
      team_branding: {
        primary_color: "not-a-color"
      }
    }
    assert_response :unprocessable_entity
  end

  test "redirects when teams disabled" do
    Settings.enable_teams = false
    sign_in @user
    get edit_team_branding_path(@team)
    assert_response :redirect
  end

  test "redirects when user branding disabled" do
    Settings.enable_user_branding = false
    sign_in @user
    get edit_team_branding_path(@team)
    assert_response :redirect
  end
end
