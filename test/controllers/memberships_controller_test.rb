# frozen_string_literal: true

require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @team = teams(:one_team)
    @admin_membership = memberships(:admin_membership)
    Settings.enable_teams = true
  end

  teardown do
    Settings.enable_teams = false
  end

  test "update changes role for admin" do
    sign_in @user # owner
    patch team_membership_path(@team, @admin_membership), params: {
      membership: { role: "member" }
    }
    assert_response :redirect
    assert_equal "member", @admin_membership.reload.role
  end

  test "update cannot change owner role" do
    sign_in @user # owner
    owner_membership = memberships(:owner_membership)
    patch team_membership_path(@team, owner_membership), params: {
      membership: { role: "member" }
    }
    assert_response :redirect
    assert_equal "owner", owner_membership.reload.role
  end

  test "destroy allows member to leave" do
    # Add a member first
    member_user = users(:luca)
    membership = @team.memberships.create!(user: member_user, role: :member)

    sign_in member_user
    assert_difference "@team.memberships.count", -1 do
      delete team_membership_path(@team, membership)
    end
    assert_response :redirect
  end

  test "destroy prevents owner from leaving" do
    sign_in @user
    owner_membership = memberships(:owner_membership)
    assert_no_difference "@team.memberships.count" do
      delete team_membership_path(@team, owner_membership)
    end
    assert_response :redirect
  end

  test "destroy allows admin to remove member" do
    sign_in users(:giuliana) # admin
    member_user = users(:luca)
    membership = @team.memberships.create!(user: member_user, role: :member)

    assert_difference "@team.memberships.count", -1 do
      delete team_membership_path(@team, membership)
    end
    assert_response :redirect
  end
end
