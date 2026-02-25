# frozen_string_literal: true

require "test_helper"

class Api::V1::TeamTwoFactorControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_teams = true
    Settings.enable_two_factor = true
    @user = users(:one)
    sign_in @user
    @team = teams(:one_team)
  end

  teardown do
    Settings.enable_teams = false
    Settings.enable_two_factor = false
  end

  test "show returns 2FA compliance" do
    get api_v1_team_two_factor_path(@team.slug, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("require_two_factor")
    assert json.key?("compliance_percentage")
    assert json.key?("total_members")
    assert json.key?("non_compliant_members")
    assert json["non_compliant_members"].is_a?(Array)
  end

  test "update toggles require_two_factor" do
    patch api_v1_team_two_factor_path(@team.slug, format: :json), params: {require_two_factor: true}
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["require_two_factor"]
    @team.reload
    assert @team.require_two_factor
  end

  test "admin can update 2FA enforcement" do
    sign_in users(:giuliana)
    patch api_v1_team_two_factor_path(@team.slug, format: :json), params: {require_two_factor: true}
    assert_response :success
  end

  test "remind returns non-compliant members" do
    post remind_api_v1_team_two_factor_path(@team.slug, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("reminded")
    assert json.key?("message")
  end

  test "teams feature disabled returns not found" do
    Settings.enable_teams = false
    get api_v1_team_two_factor_path(@team.slug, format: :json)
    assert_response :not_found
  end

  test "two_factor feature disabled returns not found" do
    Settings.enable_two_factor = false
    get api_v1_team_two_factor_path(@team.slug, format: :json)
    assert_response :not_found
  end

  test "unauthenticated returns unauthorized" do
    sign_out @user
    get api_v1_team_two_factor_path(@team.slug, format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end
end
