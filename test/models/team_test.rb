# frozen_string_literal: true

require "test_helper"

class TeamTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "creates with valid attributes" do
    team = Team.new(name: "Test Team", owner: @user)
    assert team.save
    assert team.slug.present?
  end

  test "requires name" do
    team = Team.new(owner: @user)
    assert_not team.valid?
    assert team.errors[:name].any?
  end

  test "generates slug from name" do
    team = Team.create!(name: "My Great Team", owner: @user)
    assert_equal "my-great-team", team.slug
  end

  test "ensures slug uniqueness" do
    Team.create!(name: "Unique", owner: @user)
    team2 = Team.create!(name: "Unique", owner: @user)
    assert_equal "unique-1", team2.slug
  end

  test "validates slug format" do
    team = Team.new(name: "Test", owner: @user, slug: "invalid slug!")
    assert_not team.valid?
    assert team.errors[:slug].any?
  end

  test "to_param returns slug" do
    team = teams(:one_team)
    assert_equal "acme-corp", team.to_param
  end

  test "adds owner as member on create" do
    team = Team.create!(name: "Auto Member", owner: @user)
    assert team.member?(@user)
    assert_equal "owner", team.membership_for(@user).role
  end

  test "member? returns true for member" do
    team = teams(:one_team)
    assert team.member?(@user)
  end

  test "member? returns false for non-member" do
    team = teams(:one_team)
    non_member = users(:luca)
    assert_not team.member?(non_member)
  end

  test "admin? returns true for admin and owner" do
    team = teams(:one_team)
    assert team.admin?(@user) # owner
    assert team.admin?(users(:giuliana)) # admin
  end

  test "owner? returns true for team owner" do
    team = teams(:one_team)
    assert team.owner?(@user)
    assert_not team.owner?(users(:giuliana))
  end

  test "member_count returns correct count" do
    team = teams(:one_team)
    assert_equal 2, team.member_count
  end

  test "user has_many teams" do
    assert @user.respond_to?(:teams)
    assert @user.teams.count > 0
  end

  test "user has_many owned_teams" do
    assert @user.respond_to?(:owned_teams)
  end

  test "destroying team nullifies pushes" do
    team = Team.create!(name: "Destroy Test", owner: @user)
    push = Push.create!(kind: :text, payload: "test", user: @user, team: team)
    team.destroy
    assert_nil push.reload.team_id
  end
end
