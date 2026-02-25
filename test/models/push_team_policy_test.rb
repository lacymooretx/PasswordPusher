# frozen_string_literal: true

require "test_helper"

class PushTeamPolicyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @team = teams(:one_team)
    Settings.enable_teams = true
  end

  teardown do
    Settings.enable_teams = false
  end

  test "push uses global defaults without team" do
    push = Push.create!(kind: :text, payload: "test", user: @user)
    assert_equal Settings.pw.expire_after_days_default, push.expire_after_days
  end

  test "push uses team default when set" do
    @team.update!(policy: {"defaults" => {"pw" => {"expire_after_days" => 14}}})
    push = Push.create!(kind: :text, payload: "test", user: @user, team: @team)
    assert_equal 14, push.expire_after_days
  end

  test "push uses team forced value over user input" do
    @team.update!(policy: {
      "defaults" => {"pw" => {"expire_after_days" => 14}},
      "forced" => {"pw" => {"expire_after_days" => true}}
    })
    push = Push.new(kind: :text, payload: "test", user: @user, team: @team, expire_after_days: 30)
    push.save!
    assert_equal 14, push.expire_after_days
  end

  test "push falls back to global when no team policy" do
    push = Push.create!(kind: :text, payload: "test", user: @user, team: @team)
    assert_equal Settings.pw.expire_after_days_default, push.expire_after_days
  end

  test "team forced clamps to global limits" do
    @team.update!(policy: {
      "defaults" => {"pw" => {"expire_after_days" => 999}},
      "forced" => {"pw" => {"expire_after_days" => true}}
    })
    push = Push.create!(kind: :text, payload: "test", user: @user, team: @team)
    # 999 is outside global max (90), should be clamped to default
    assert_equal Settings.pw.expire_after_days_default, push.expire_after_days
  end
end
