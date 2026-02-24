# frozen_string_literal: true

require "test_helper"

class TeamPoliciesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @team = teams(:one_team)
    Settings.enable_teams = true
  end

  teardown do
    Settings.enable_teams = false
  end

  test "edit shows policy form" do
    sign_in @user
    get edit_team_policy_path(@team)
    assert_response :success
  end

  test "edit requires team admin" do
    # Add a regular member
    member = users(:luca)
    @team.memberships.create!(user: member, role: :member)

    sign_in member
    get edit_team_policy_path(@team)
    assert_response :redirect
  end

  test "update saves policy" do
    sign_in @user
    patch team_policy_path(@team), params: {
      policy: {
        defaults: { pw: { expire_after_days: "14", expire_after_views: "10" } },
        forced: { pw: { expire_after_days: "1" } },
        hidden_features: { url_pushes: "1" },
        limits: { pw: { expire_after_days_max: "30" } }
      }
    }
    assert_response :redirect
    @team.reload
    assert_equal 14, @team.policy.dig("defaults", "pw", "expire_after_days")
    assert @team.policy.dig("forced", "pw", "expire_after_days")
    assert @team.policy.dig("hidden_features", "url_pushes")
    assert_equal 30, @team.policy.dig("limits", "pw", "expire_after_days_max")
  end

  test "update clears empty values" do
    @team.update!(policy: { "defaults" => { "pw" => { "expire_after_days" => 14 } } })
    sign_in @user
    patch team_policy_path(@team), params: {
      policy: { defaults: { pw: { expire_after_days: "" } } }
    }
    assert_response :redirect
    @team.reload
    assert_nil @team.policy.dig("defaults", "pw", "expire_after_days")
  end

  test "redirects when feature disabled" do
    Settings.enable_teams = false
    sign_in @user
    get edit_team_policy_path(@team)
    assert_response :redirect
  end
end
