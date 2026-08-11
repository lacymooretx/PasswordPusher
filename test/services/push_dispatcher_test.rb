# frozen_string_literal: true

require "test_helper"

class PushDispatcherTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @push = pushes(:test_push)
    @secret_url = "https://pwpush.test/p/#{@push.url_token}"

    Settings.enable_auto_dispatch = true
    Settings.enable_sms_dispatch = true
    Settings.auto_dispatch = Config::Options.new(
      max_recipients: 10, max_sms_recipients: 5, enable_supervisor: true
    )
  end

  teardown do
    Settings.enable_auto_dispatch = false
    Settings.enable_sms_dispatch = false
  end

  # **spec so specs can be written inline (dispatch(emails: "...")) without Ruby
  # folding them into the keyword arguments of this helper.
  def dispatch(**spec)
    PushDispatcher.call(push: @push, secret_url: @secret_url, spec: spec, enqueue: false)
  end

  def dispatch_and_enqueue(**spec)
    PushDispatcher.call(push: @push, secret_url: @secret_url, spec: spec, enqueue: true)
  end

  # -- email --------------------------------------------------------------

  test "creates a pending email dispatch per valid recipient" do
    result = dispatch(emails: "alice@example.com, bob@example.com")

    assert_equal 2, result.email_count
    assert result.dispatches.all? { |d| d.email? && d.recipient? && d.pending? }
    assert_equal ["alice@example.com", "bob@example.com"], result.dispatches.map(&:destination)
  end

  test "reports invalid email addresses instead of silently dropping them" do
    result = dispatch(emails: "alice@example.com, not-an-email")

    assert_equal 1, result.email_count
    assert_equal 1, result.errors.size
    assert_match(/not-an-email/, result.errors.first)
  end

  test "caps email recipients at max_recipients and says so" do
    Settings.auto_dispatch = Config::Options.new(max_recipients: 1, max_sms_recipients: 5, enable_supervisor: true)

    result = dispatch(emails: "a@example.com, b@example.com, c@example.com")

    assert_equal 1, result.email_count
    assert_match(/Only the first 1 email recipient/, result.errors.first)
  end

  test "accepts an array of emails from the API" do
    result = dispatch(emails: ["alice@example.com", "bob@example.com"])

    assert_equal 2, result.email_count
  end

  # -- sms ----------------------------------------------------------------

  test "normalizes phone numbers into E.164 sms dispatches" do
    result = dispatch(phones: "713-875-0817")

    assert_equal 1, result.sms_count
    assert_equal "+17138750817", result.dispatches.first.destination
    assert result.dispatches.first.sms?
  end

  test "reports unparseable phone numbers" do
    result = dispatch(phones: "713-875-0817, banana")

    assert_equal 1, result.sms_count
    assert(result.errors.any? { |e| e.include?("banana") })
  end

  test "caps sms recipients at max_sms_recipients" do
    Settings.auto_dispatch = Config::Options.new(max_recipients: 10, max_sms_recipients: 1, enable_supervisor: true)

    result = dispatch(phones: "713-875-0817, 281-941-4028")

    assert_equal 1, result.sms_count
    assert(result.errors.any? { |e| e.include?("Only the first 1 SMS recipient") })
  end

  test "refuses sms when the sms feature flag is off" do
    Settings.enable_sms_dispatch = false

    result = dispatch(phones: "713-875-0817")

    assert_equal 0, result.sms_count
    assert_includes result.errors, "SMS dispatch is not enabled."
  end

  # -- supervisor ---------------------------------------------------------

  test "creates supervisor email and sms dispatches tagged with the supervisor role" do
    result = dispatch(
      emails: "alice@example.com",
      phones: "713-875-0817",
      supervisor_email: "boss@example.com",
      supervisor_phone: "281-941-4028"
    )

    supervisors = result.dispatches.select(&:supervisor?)
    assert_equal 2, supervisors.size
    assert_equal ["boss@example.com", "+12819414028"], supervisors.map(&:destination)
    assert_equal [:email, :sms], supervisors.map { |d| d.channel.to_sym }
  end

  test "reports an invalid supervisor address" do
    result = dispatch(supervisor_email: "nope")

    assert_empty result.dispatches
    assert_match(/Supervisor email address is not valid/, result.errors.first)
  end

  test "refuses supervisor dispatch when the setting is off" do
    Settings.auto_dispatch = Config::Options.new(max_recipients: 10, max_sms_recipients: 5, enable_supervisor: false)

    result = dispatch(supervisor_email: "boss@example.com")

    assert_empty result.dispatches
    assert_includes result.errors, "Supervisor dispatch is not enabled."
  end

  # -- gating & queueing --------------------------------------------------

  test "does nothing when auto dispatch is disabled" do
    Settings.enable_auto_dispatch = false

    result = dispatch(emails: "alice@example.com")

    assert_empty result.dispatches
    assert_includes result.errors, "Auto dispatch is not enabled."
  end

  test "enqueues one delivery job per dispatch" do
    assert_enqueued_jobs 2, only: PushDispatchJob do
      dispatch_and_enqueue(emails: "alice@example.com", phones: "713-875-0817")
    end
  end

  # -- sms body -----------------------------------------------------------

  test "sms body carries the link, expiration and a passphrase hint but never the passphrase" do
    @push.update!(passphrase: "hunter2", expire_after_days: 3, expire_after_views: 2)

    body = PushDispatcher.sms_body(@push, @secret_url)

    assert_includes body, @secret_url
    assert_includes body, "3 day(s)"
    assert_includes body, "2 view(s)"
    assert_includes body, "passphrase is required"
    assert_not_includes body, "hunter2"
  end

  test "sms body tells a supervisor why they were copied" do
    body = PushDispatcher.sms_body(@push, @secret_url, role: :supervisor)

    assert_includes body, "supervisor"
  end
end
