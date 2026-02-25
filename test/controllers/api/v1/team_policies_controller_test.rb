# frozen_string_literal: true

require "test_helper"

class Api::V1::TeamPoliciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_teams = true
    @team = teams(:one_team)
    @owner = users(:one)
    @admin = users(:giuliana)
    sign_in @owner
  end

  teardown do
    Settings.enable_teams = false
  end

  # --- show ---

  test "show returns policy JSON as owner" do
    get api_v1_team_policy_path(team_id: @team.slug, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @team.slug, json["team_slug"]
    assert_equal @team.name, json["team_name"]
    assert json.key?("policy")
  end

  test "show returns policy JSON as admin" do
    sign_in @admin
    get api_v1_team_policy_path(team_id: @team.slug, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @team.slug, json["team_slug"]
  end

  # --- update ---

  test "update saves policy" do
    policy_data = {
      "defaults" => {"pw" => {"expire_after_days" => 5}},
      "forced" => {"pw" => {"expire_after_days" => true}},
      "hidden_features" => {"url_pushes" => true},
      "limits" => {"pw" => {"expire_after_days_max" => 30}}
    }
    patch api_v1_team_policy_path(team_id: @team.slug, format: :json),
      params: {policy: policy_data}.to_json,
      headers: {"Content-Type" => "application/json"}
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 5, json.dig("policy", "defaults", "pw", "expire_after_days")
    assert_equal true, json.dig("policy", "forced", "pw", "expire_after_days")
    assert_equal true, json.dig("policy", "hidden_features", "url_pushes")
    assert_equal 30, json.dig("policy", "limits", "pw", "expire_after_days_max")

    # Verify persisted
    @team.reload
    assert_equal 5, @team.policy.dig("defaults", "pw", "expire_after_days")
  end

  # --- non-admin ---

  test "non-admin returns forbidden" do
    # luca is not a member of one_team
    sign_in users(:luca)
    get api_v1_team_policy_path(team_id: @team.slug, format: :json)
    assert_response :not_found
  end

  test "regular member without admin role returns forbidden" do
    # Create a regular member for this test
    member_user = users(:luca)
    Membership.create!(team: @team, user: member_user, role: :member)

    sign_in member_user
    get api_v1_team_policy_path(team_id: @team.slug, format: :json)
    assert_response :forbidden
  end

  # --- feature disabled ---

  test "feature disabled returns not found" do
    Settings.enable_teams = false
    get api_v1_team_policy_path(team_id: @team.slug, format: :json)
    assert_response :not_found
  end

  # --- unauthenticated ---

  test "unauthenticated returns unauthorized" do
    sign_out @owner
    get api_v1_team_policy_path(team_id: @team.slug, format: :json),
      headers: {"X-User-Email" => "bad@example.com", "X-User-Token" => "invalid"}
    assert_response :unauthorized
  end

  # --- token auth ---

  test "token auth works for show" do
    sign_out @owner
    get api_v1_team_policy_path(team_id: @team.slug, format: :json),
      headers: {"X-User-Email" => @owner.email, "X-User-Token" => @owner.authentication_token}
    assert_response :success
  end
end
