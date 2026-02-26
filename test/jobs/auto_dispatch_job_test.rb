# frozen_string_literal: true

require "test_helper"

class AutoDispatchJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    Settings.enable_auto_dispatch = true
    Settings.auto_dispatch = Config::Options.new(max_recipients: 10)
  end

  teardown do
    Settings.enable_auto_dispatch = false
  end

  test "dispatches emails for valid push" do
    push = pushes(:test_push)
    secret_url = "https://pwpush.test/p/#{push.url_token}"
    emails = ["alice@example.com", "bob@example.com"]

    assert_enqueued_emails 2 do
      AutoDispatchJob.perform_now(push.id, secret_url, emails)
    end
  end

  test "respects max_recipients limit" do
    Settings.auto_dispatch = Config::Options.new(max_recipients: 1)

    push = pushes(:test_push)
    secret_url = "https://pwpush.test/p/#{push.url_token}"
    emails = ["alice@example.com", "bob@example.com", "carol@example.com"]

    assert_enqueued_emails 1 do
      AutoDispatchJob.perform_now(push.id, secret_url, emails)
    end
  end

  test "does nothing when feature flag disabled" do
    Settings.enable_auto_dispatch = false

    push = pushes(:test_push)
    secret_url = "https://pwpush.test/p/#{push.url_token}"
    emails = ["alice@example.com"]

    assert_no_enqueued_emails do
      AutoDispatchJob.perform_now(push.id, secret_url, emails)
    end
  end

  test "does nothing for nonexistent push" do
    secret_url = "https://pwpush.test/p/fake"
    emails = ["alice@example.com"]

    assert_no_enqueued_emails do
      AutoDispatchJob.perform_now(-1, secret_url, emails)
    end
  end
end
