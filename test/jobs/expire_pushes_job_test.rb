# frozen_string_literal: true

require "test_helper"

class ExpirePushesJobTest < ActiveJob::TestCase
  test "expires push that has exceeded its view limit" do
    push = Push.create!(
      kind: :text,
      payload: "secret-view-exceeded",
      expire_after_days: 7,
      expire_after_views: 2
    )

    # Simulate 2 views (meets the limit)
    2.times { push.audit_logs.create!(kind: :view, ip: "127.0.0.1") }

    assert_not push.expired, "Push should not be expired before running job"

    ExpirePushesJob.perform_now

    push.reload
    assert push.expired, "Push should be expired after exceeding view limit"
    assert_not_nil push.expired_on
  end

  test "does not expire push within limits" do
    push = Push.create!(
      kind: :text,
      payload: "secret-within-limits",
      expire_after_days: 7,
      expire_after_views: 10
    )

    # Simulate 1 view (well within limit)
    push.audit_logs.create!(kind: :view, ip: "127.0.0.1")

    ExpirePushesJob.perform_now

    push.reload
    assert_not push.expired, "Push within limits should not be expired"
  end

  test "expires push that has exceeded its day limit" do
    push = Push.create!(
      kind: :text,
      payload: "secret-day-exceeded",
      expire_after_days: 3,
      expire_after_views: 99
    )

    # Backdate created_at so days_old > expire_after_days
    push.update_columns(created_at: 4.days.ago)

    assert_not push.expired, "Push should not be expired before running job"

    ExpirePushesJob.perform_now

    push.reload
    assert push.expired, "Push should be expired after exceeding day limit"
    assert_not_nil push.expired_on
  end
end
