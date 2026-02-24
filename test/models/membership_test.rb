# frozen_string_literal: true

require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "validates uniqueness of user per team" do
    team = teams(:one_team)
    user = users(:one)
    dup = team.memberships.build(user: user, role: :member)
    assert_not dup.valid?
  end

  test "role enum works" do
    m = Membership.new(role: :member)
    assert m.member?

    m.role = :admin
    assert m.admin?

    m.role = :owner
    assert m.owner?
  end

  test "can_manage_members? for admin" do
    admin = memberships(:admin_membership)
    assert admin.can_manage_members?
  end

  test "can_manage_members? false for member" do
    team = teams(:one_team)
    member_user = users(:luca)
    team.memberships.create!(user: member_user, role: :member)
    membership = team.membership_for(member_user)
    assert_not membership.can_manage_members?
  end

  test "removable_by? owner can remove admin" do
    owner = memberships(:owner_membership)
    admin = memberships(:admin_membership)
    assert admin.removable_by?(owner)
  end

  test "removable_by? owner cannot be removed" do
    owner = memberships(:owner_membership)
    admin = memberships(:admin_membership)
    assert_not owner.removable_by?(admin)
  end
end
