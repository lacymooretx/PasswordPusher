# frozen_string_literal: true

require "test_helper"

class TeamsNotificationJobTest < ActiveJob::TestCase
  test "skips when feature disabled" do
    Settings.enable_teams_notifications = false
    push = pushes(:test_push)

    assert_nothing_raised do
      TeamsNotificationJob.perform_now(push.id, "push.created")
    end
  end

  test "skips when push not found" do
    Settings.enable_teams_notifications = true
    assert_nothing_raised do
      TeamsNotificationJob.perform_now(-1, "push.created")
    end
  ensure
    Settings.enable_teams_notifications = false
  end
end
