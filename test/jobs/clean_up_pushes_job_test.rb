# frozen_string_literal: true

require "test_helper"

class CleanUpPushesJobTest < ActiveJob::TestCase
  test "destroys expired anonymous push" do
    push = Push.create!(
      kind: :text,
      payload: "anonymous-expired",
      expire_after_days: 7,
      expire_after_views: 5
    )
    push.expire!

    assert push.reload.expired
    assert_nil push.user_id

    CleanUpPushesJob.perform_now

    assert_not Push.exists?(push.id), "Expired anonymous push should be destroyed"
  end

  test "does not destroy expired push with user" do
    push = pushes(:test_push)
    push.expire!

    assert push.reload.expired
    assert_not_nil push.user_id

    CleanUpPushesJob.perform_now

    assert Push.exists?(push.id), "Expired push with user should still exist"
  end

  test "does not destroy non-expired anonymous push" do
    push = Push.create!(
      kind: :text,
      payload: "anonymous-active",
      expire_after_days: 7,
      expire_after_views: 5
    )

    assert_not push.expired
    assert_nil push.user_id

    CleanUpPushesJob.perform_now

    assert Push.exists?(push.id), "Non-expired anonymous push should still exist"
  end
end
