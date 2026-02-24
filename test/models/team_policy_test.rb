# frozen_string_literal: true

require "test_helper"

class TeamPolicyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @team = teams(:one_team)
  end

  test "policy defaults to empty hash" do
    assert_equal({}, @team.policy)
  end

  test "policy_default returns value when set" do
    @team.update!(policy: { "defaults" => { "pw" => { "expire_after_days" => 14 } } })
    assert_equal 14, @team.policy_default(:pw, :expire_after_days)
  end

  test "policy_default returns nil when not set" do
    assert_nil @team.policy_default(:pw, :expire_after_days)
  end

  test "policy_forced? returns true when set" do
    @team.update!(policy: {
      "defaults" => { "pw" => { "expire_after_days" => 14 } },
      "forced" => { "pw" => { "expire_after_days" => true } }
    })
    assert @team.policy_forced?(:pw, :expire_after_days)
  end

  test "policy_forced? returns false when not set" do
    assert_not @team.policy_forced?(:pw, :expire_after_days)
  end

  test "policy_forced_value returns value when forced" do
    @team.update!(policy: {
      "defaults" => { "pw" => { "expire_after_days" => 14 } },
      "forced" => { "pw" => { "expire_after_days" => true } }
    })
    assert_equal 14, @team.policy_forced_value(:pw, :expire_after_days)
  end

  test "policy_forced_value returns nil when not forced" do
    @team.update!(policy: { "defaults" => { "pw" => { "expire_after_days" => 14 } } })
    assert_nil @team.policy_forced_value(:pw, :expire_after_days)
  end

  test "feature_hidden? returns true when hidden" do
    @team.update!(policy: { "hidden_features" => { "url_pushes" => true } })
    assert @team.feature_hidden?(:url_pushes)
  end

  test "feature_hidden? returns false when not hidden" do
    assert_not @team.feature_hidden?(:url_pushes)
  end

  test "policy_limit returns value when set" do
    @team.update!(policy: { "limits" => { "pw" => { "expire_after_days_max" => 30 } } })
    assert_equal 30, @team.policy_limit(:pw, :expire_after_days_max)
  end

  test "hidden_features returns hash" do
    @team.update!(policy: { "hidden_features" => { "url_pushes" => true, "file_pushes" => true } })
    assert_equal({ "url_pushes" => true, "file_pushes" => true }, @team.hidden_features)
  end
end
