# frozen_string_literal: true

require "test_helper"

class TeamInvitationTest < ActiveSupport::TestCase
  setup do
    @team = teams(:one_team)
    @user = users(:one)
  end

  test "creates with valid attributes" do
    inv = TeamInvitation.new(team: @team, invited_by: @user, email: "test@example.com")
    assert inv.save
    assert inv.token.present?
    assert inv.expires_at.present?
  end

  test "requires email" do
    inv = TeamInvitation.new(team: @team, invited_by: @user)
    assert_not inv.valid?
    assert inv.errors[:email].any?
  end

  test "validates email format" do
    inv = TeamInvitation.new(team: @team, invited_by: @user, email: "not-an-email")
    assert_not inv.valid?
  end

  test "validates email uniqueness per team" do
    TeamInvitation.create!(team: @team, invited_by: @user, email: "unique@example.com")
    dup = TeamInvitation.new(team: @team, invited_by: @user, email: "unique@example.com")
    assert_not dup.valid?
  end

  test "generates token on create" do
    inv = TeamInvitation.create!(team: @team, invited_by: @user, email: "token@example.com")
    assert inv.token.present?
    assert inv.token.length > 10
  end

  test "sets default expiration" do
    inv = TeamInvitation.create!(team: @team, invited_by: @user, email: "expire@example.com")
    assert inv.expires_at > 6.days.from_now
  end

  test "pending? returns true for valid invitation" do
    inv = team_invitations(:pending_invitation)
    assert inv.pending?
  end

  test "expired? returns true for old invitation" do
    inv = team_invitations(:expired_invitation)
    assert inv.expired?
  end

  test "accept! adds user to team" do
    inv = team_invitations(:pending_invitation)
    new_user = users(:luca)
    assert inv.accept!(new_user)
    assert @team.member?(new_user)
    assert inv.reload.accepted?
  end

  test "accept! fails for expired invitation" do
    inv = team_invitations(:expired_invitation)
    new_user = users(:luca)
    assert_not inv.accept!(new_user)
  end

  test "accept! fails for existing member" do
    inv = team_invitations(:pending_invitation)
    assert_not inv.accept!(@user) # already a member
  end

  test "pending scope excludes expired" do
    assert_not TeamInvitation.pending.include?(team_invitations(:expired_invitation))
  end
end
