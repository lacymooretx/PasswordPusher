# frozen_string_literal: true

require "test_helper"

class ClamavHealthCheckJobTest < ActiveJob::TestCase
  setup do
    # The test environment uses :null_store, which silently drops everything.
    # This job's grace period and throttle are state-driven, so swap in a real
    # store; the null-store behaviour gets its own test below.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    ActionMailer::Base.deliveries.clear
    @original_enable_clamav = Settings.enable_clamav
    Settings.enable_clamav = true
  end

  teardown do
    Rails.cache = @original_cache
    Settings.enable_clamav = @original_enable_clamav
  end

  # Alerts go out via deliver_later, so drain the queue to inspect them.
  def run_job_and_deliver
    perform_enqueued_jobs { ClamavHealthCheckJob.perform_now }
  end

  def state
    Rails.cache.read(ClamavHealthCheckJob::STATE_KEY)&.symbolize_keys || {}
  end

  def stub_available(value, &)
    ClamavScanner.stub(:available?, value, &)
  end

  test "does nothing when clamav is disabled" do
    Settings.enable_clamav = false
    stub_available(false) { run_job_and_deliver }

    assert_empty state
    assert_empty ActionMailer::Base.deliveries
  end

  test "healthy scanner writes no state and sends nothing" do
    stub_available(true) { run_job_and_deliver }

    assert_empty state
    assert_empty ActionMailer::Base.deliveries
  end

  test "records the outage but stays quiet during the grace period" do
    stub_available(false) { run_job_and_deliver }

    assert state[:down_since].present?, "should record when the outage started"
    assert_nil state[:alerted_at], "should not alert inside the grace period"
    assert_empty ActionMailer::Base.deliveries
  end

  test "alerts once the grace period has elapsed" do
    Rails.cache.write(
      ClamavHealthCheckJob::STATE_KEY,
      {down_since: 1.hour.ago},
      expires_in: ClamavHealthCheckJob::STATE_TTL
    )

    stub_available(false) { run_job_and_deliver }

    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_match(/unreachable/i, mail.subject)
    assert_match(/not being scanned/i, mail.subject)
    assert state[:alerted_at].present?
  end

  test "does not re-alert before the re-alert window" do
    Rails.cache.write(
      ClamavHealthCheckJob::STATE_KEY,
      {down_since: 10.hours.ago, alerted_at: 1.hour.ago},
      expires_in: ClamavHealthCheckJob::STATE_TTL
    )

    stub_available(false) { run_job_and_deliver }

    assert_empty ActionMailer::Base.deliveries, "6h re-alert window has not elapsed"
  end

  test "re-alerts after the re-alert window" do
    Rails.cache.write(
      ClamavHealthCheckJob::STATE_KEY,
      {down_since: 10.hours.ago, alerted_at: 7.hours.ago},
      expires_in: ClamavHealthCheckJob::STATE_TTL
    )

    stub_available(false) { run_job_and_deliver }

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_operator state[:alerted_at], :>, 1.minute.ago
  end

  test "sends a recovery notice only if an alert was actually sent" do
    Rails.cache.write(
      ClamavHealthCheckJob::STATE_KEY,
      {down_since: 3.hours.ago, alerted_at: 2.hours.ago},
      expires_in: ClamavHealthCheckJob::STATE_TTL
    )

    stub_available(true) { run_job_and_deliver }

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_match(/recovered/i, ActionMailer::Base.deliveries.last.subject)
    assert_empty state, "state should be cleared on recovery"
  end

  test "silent blip inside the grace period produces no recovery mail" do
    Rails.cache.write(
      ClamavHealthCheckJob::STATE_KEY,
      {down_since: 1.minute.ago},
      expires_in: ClamavHealthCheckJob::STATE_TTL
    )

    stub_available(true) { run_job_and_deliver }

    assert_empty ActionMailer::Base.deliveries, "never alerted, so nothing to recover from"
    assert_empty state
  end

  test "falls back to admin users when no alert_emails are configured" do
    Rails.cache.write(
      ClamavHealthCheckJob::STATE_KEY,
      {down_since: 1.hour.ago},
      expires_in: ClamavHealthCheckJob::STATE_TTL
    )

    stub_available(false) { run_job_and_deliver }

    admin_emails = User.where(admin: true).pluck(:email)
    assert admin_emails.any?, "fixture should provide at least one admin"
    assert_equal admin_emails.sort, ActionMailer::Base.deliveries.last.to.sort
  end

  # The YAML form is a list, but the PWP__CLAMAV__HEALTH_CHECK__ALERT_EMAILS
  # env override arrives as one comma-separated string. Both must work.
  [
    ["a YAML list", ["ops@example.com", "sec@example.com"]],
    ["a comma-separated env string", "ops@example.com, sec@example.com"]
  ].each do |label, configured|
    test "uses configured alert_emails given as #{label}" do
      original = Settings.clamav.health_check.alert_emails
      Settings.clamav.health_check.alert_emails = configured

      Rails.cache.write(
        ClamavHealthCheckJob::STATE_KEY,
        {down_since: 1.hour.ago},
        expires_in: ClamavHealthCheckJob::STATE_TTL
      )

      begin
        stub_available(false) { run_job_and_deliver }
      ensure
        Settings.clamav.health_check.alert_emails = original
      end

      assert_equal ["ops@example.com", "sec@example.com"],
        ActionMailer::Base.deliveries.last.to.sort
    end
  end

  # Regression guard: with a store that never retains state, every run looks
  # like a fresh outage, so a naive implementation sits inside the grace period
  # forever and never alerts at all -- the same silent failure this job exists
  # to catch. It must degrade to alerting rather than to silence.
  test "alerts every run when the cache cannot retain state" do
    Rails.cache = ActiveSupport::Cache::NullStore.new

    stub_available(false) do
      run_job_and_deliver
      run_job_and_deliver
    end

    assert_equal 2, ActionMailer::Base.deliveries.size,
      "a non-retaining cache must degrade to alerting, never to silence"
  end

  test "a probe that raises is treated as unavailable, not as a crash" do
    Rails.cache.write(
      ClamavHealthCheckJob::STATE_KEY,
      {down_since: 1.hour.ago},
      expires_in: ClamavHealthCheckJob::STATE_TTL
    )

    ClamavScanner.stub(:available?, ->(*) { raise Errno::ECONNREFUSED }) do
      assert_nothing_raised { run_job_and_deliver }
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
  end
end
