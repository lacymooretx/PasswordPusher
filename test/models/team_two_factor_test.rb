# frozen_string_literal: true

require "test_helper"

class TeamTwoFactorTest < ActiveSupport::TestCase
  setup do
    @team = teams(:one_team)
  end

  test "members_without_2fa returns non-2fa members" do
    # By default no one has 2FA enabled
    assert @team.members_without_2fa.count > 0
  end

  test "members_without_2fa excludes 2fa users" do
    user = users(:one)
    user.update!(otp_required_for_login: true, otp_secret: ROTP::Base32.random)
    without = @team.members_without_2fa
    assert_not without.include?(user)
  end

  test "two_factor_compliance_percentage with no 2fa" do
    assert @team.two_factor_compliance_percentage < 100
  end

  test "two_factor_compliance_percentage with all 2fa" do
    @team.users.each do |user|
      user.update!(otp_required_for_login: true, otp_secret: ROTP::Base32.random)
    end
    assert_equal 100, @team.two_factor_compliance_percentage
  end

  test "require_two_factor defaults to false" do
    team = Team.create!(name: "New Team", owner: users(:one))
    assert_not team.require_two_factor?
  end
end
