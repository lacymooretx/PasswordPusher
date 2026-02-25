# frozen_string_literal: true

require "test_helper"

class PurgeExpiredPushesJobTest < ActiveJob::TestCase
  teardown do
    Settings.reload!
  end

  test "destroys expired push older than purge_after duration" do
    Settings.purge_after = "7 days"

    push = Push.create!(
      kind: :text,
      payload: "old-expired",
      expire_after_days: 1,
      expire_after_views: 5
    )
    push.expire!
    push.update_columns(expired_on: 8.days.ago)

    PurgeExpiredPushesJob.perform_now

    assert_not Push.exists?(push.id), "Push expired 8 days ago should be destroyed with 7-day purge_after"
  end

  test "does not destroy expired push within purge_after duration" do
    Settings.purge_after = "7 days"

    push = Push.create!(
      kind: :text,
      payload: "recent-expired",
      expire_after_days: 1,
      expire_after_views: 5
    )
    push.expire!
    push.update_columns(expired_on: 3.days.ago)

    PurgeExpiredPushesJob.perform_now

    assert Push.exists?(push.id), "Push expired 3 days ago should still exist with 7-day purge_after"
  end

  test "does nothing when purge_after is disabled" do
    Settings.purge_after = "disabled"

    push = Push.create!(
      kind: :text,
      payload: "disabled-purge",
      expire_after_days: 1,
      expire_after_views: 5
    )
    push.expire!
    push.update_columns(expired_on: 365.days.ago)

    PurgeExpiredPushesJob.perform_now

    assert Push.exists?(push.id), "Push should not be destroyed when purge_after is disabled"
  end
end
