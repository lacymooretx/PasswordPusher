# frozen_string_literal: true

require "test_helper"

class PushDispatchJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

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

  def email_dispatch(role: :recipient, destination: "alice@example.com")
    PushDispatch.create!(push: @push, channel: :email, role: role, status: :pending, destination: destination)
  end

  def sms_dispatch(role: :recipient, destination: "+17138750817")
    PushDispatch.create!(push: @push, channel: :sms, role: role, status: :pending, destination: destination)
  end

  # -- email --------------------------------------------------------------

  test "delivers the secret link email and marks the dispatch sent" do
    dispatch = email_dispatch

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      PushDispatchJob.perform_now(dispatch.id, @secret_url)
    end

    dispatch.reload
    assert dispatch.sent?
    assert dispatch.sent_at.present?
    assert_nil dispatch.error

    mail = ActionMailer::Base.deliveries.last
    assert_equal ["alice@example.com"], mail.to
    assert_includes mail.body.encoded, @push.url_token
  end

  test "supervisor emails say the recipient was copied as supervisor" do
    dispatch = email_dispatch(role: :supervisor, destination: "boss@example.com")

    PushDispatchJob.perform_now(dispatch.id, @secret_url)

    mail = ActionMailer::Base.deliveries.last
    assert_match(/supervisor/i, mail.subject)
    assert_equal ["boss@example.com"], mail.to
  end

  # A provider rejection must land on the row, not vanish because
  # raise_delivery_errors defaults to false.
  test "records an email delivery failure on the dispatch row" do
    dispatch = email_dispatch

    failing = Class.new do
      def initialize(*) = nil

      def deliver!(_mail)
        raise MailDelivery::Smtp2goApi::DeliveryError, "sender not verified"
      end
    end

    ActionMailer::Base.add_delivery_method(:failing_test, failing)
    original = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :failing_test

    begin
      PushDispatchJob.perform_now(dispatch.id, @secret_url)
    ensure
      ActionMailer::Base.delivery_method = original
    end

    dispatch.reload
    assert dispatch.failed?
    assert_match(/sender not verified/, dispatch.error)
  end

  # -- sms ----------------------------------------------------------------

  test "sends the SMS through Clerk Chat and stores the provider message id" do
    dispatch = sms_dispatch
    captured = {}

    fake = Object.new
    fake.define_singleton_method(:deliver) do |to:, body:|
      captured[:to] = to
      captured[:body] = body
      Sms::ClerkChat::Result.new(message_id: "msg_1", status: "queued")
    end

    Sms::ClerkChat.stub :new, fake do
      PushDispatchJob.perform_now(dispatch.id, @secret_url)
    end

    dispatch.reload
    assert dispatch.sent?
    assert_equal "msg_1", dispatch.provider_message_id
    assert_equal "+17138750817", captured[:to]
    assert_includes captured[:body], @secret_url
  end

  test "records an SMS delivery failure on the dispatch row" do
    dispatch = sms_dispatch

    fake = Object.new
    fake.define_singleton_method(:deliver) do |to:, body:|
      raise Sms::ClerkChat::DeliveryError, "Invalid sender number"
    end

    Sms::ClerkChat.stub :new, fake do
      PushDispatchJob.perform_now(dispatch.id, @secret_url)
    end

    dispatch.reload
    assert dispatch.failed?
    assert_match(/Invalid sender number/, dispatch.error)
  end

  test "marks SMS failed when the sms feature flag is off" do
    Settings.enable_sms_dispatch = false
    dispatch = sms_dispatch

    PushDispatchJob.perform_now(dispatch.id, @secret_url)

    dispatch.reload
    assert dispatch.failed?
    assert_match(/SMS dispatch is disabled/, dispatch.error)
  end

  # -- guards -------------------------------------------------------------

  test "marks the dispatch failed when auto dispatch has been turned off" do
    Settings.enable_auto_dispatch = false
    dispatch = email_dispatch

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      PushDispatchJob.perform_now(dispatch.id, @secret_url)
    end

    assert dispatch.reload.failed?
  end

  test "does nothing for a dispatch that no longer exists" do
    assert_nothing_raised { PushDispatchJob.perform_now(-1, @secret_url) }
  end
end
