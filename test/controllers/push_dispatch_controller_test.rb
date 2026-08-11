# frozen_string_literal: true

require "test_helper"

# Web-side dispatch: the fields on the creation form and the "email or text
# this link" panel on the preview page.
class PushDispatchControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @original_dispatch_config = Settings.auto_dispatch

    Settings.enable_logins = true
    Settings.enable_auto_dispatch = true
    Settings.enable_sms_dispatch = true
    Settings.auto_dispatch = Config::Options.new(
      max_recipients: 10, max_sms_recipients: 5, enable_supervisor: true
    )

    @luca = users(:luca)
  end

  teardown do
    Settings.enable_logins = false
    Settings.enable_auto_dispatch = false
    Settings.enable_sms_dispatch = false
    Settings.auto_dispatch = @original_dispatch_config
  end

  # -- creation form --------------------------------------------------------

  test "the new push form shows the dispatch fields to a signed in user" do
    sign_in @luca
    get new_push_path(tab: "text")

    assert_response :success
    assert_select "input#dispatch_emails"
    assert_select "input#dispatch_phones"
    assert_select "input#supervisor_email"
    assert_select "input#supervisor_phone"
  end

  test "the dispatch fields are hidden from anonymous visitors" do
    get new_push_path(tab: "text")

    assert_response :success
    assert_select "input#dispatch_emails", false
  end

  test "the sms fields are hidden when sms dispatch is off" do
    Settings.enable_sms_dispatch = false
    sign_in @luca
    get new_push_path(tab: "text")

    assert_response :success
    assert_select "input#dispatch_emails"
    assert_select "input#dispatch_phones", false
  end

  test "creating a push dispatches to the addresses on the form" do
    sign_in @luca

    assert_difference("PushDispatch.count", 3) do
      post pushes_path, params: {
        push: {kind: "text", payload: "form-secret"},
        dispatch_emails: "alice@example.com",
        dispatch_phones: "713-875-0817",
        supervisor_email: "boss@example.com"
      }
    end

    assert_response :redirect

    # Email dispatches are built before SMS ones, supervisor last within each
    # channel.
    dispatches = Push.last.push_dispatches
    assert_equal %w[email email sms], dispatches.map(&:channel)
    assert_equal %w[recipient supervisor recipient], dispatches.map(&:role)
  end

  test "an anonymous creation cannot dispatch" do
    Settings.allow_anonymous = true

    assert_no_difference("PushDispatch.count") do
      post pushes_path, params: {
        push: {kind: "text", payload: "anon-secret"},
        dispatch_emails: "victim@example.com"
      }
    end
  end

  # -- preview page ---------------------------------------------------------

  test "the preview page offers to email or text the link" do
    sign_in @luca
    push = Push.create!(kind: "text", payload: "preview-secret", user: @luca)

    get preview_push_path(push)

    assert_response :success
    assert_select "input#preview_dispatch_emails"
    assert_select "input#preview_dispatch_phones"
  end

  test "dispatching from the preview page queues the deliveries" do
    sign_in @luca
    push = Push.create!(kind: "text", payload: "preview-secret", user: @luca)

    assert_difference("PushDispatch.count", 2) do
      post dispatch_push_path(push), params: {
        dispatch_emails: "alice@example.com",
        dispatch_phones: "713-875-0817"
      }
    end

    assert_redirected_to preview_push_path(push)
    assert_match(/emailed to 1 recipient/, flash[:notice])
    assert_match(/texted to 1 number/, flash[:notice])
  end

  test "dispatch reports refused addresses in the flash" do
    sign_in @luca
    push = Push.create!(kind: "text", payload: "preview-secret", user: @luca)

    post dispatch_push_path(push), params: {dispatch_emails: "nope"}

    assert_redirected_to preview_push_path(push)
    assert_match(/not valid/, flash[:alert])
  end

  test "a user cannot dispatch someone else's push" do
    sign_in @luca
    other_push = Push.create!(kind: "text", payload: "not-mine", user: users(:one))

    assert_no_difference("PushDispatch.count") do
      post dispatch_push_path(other_push), params: {dispatch_emails: "alice@example.com"}
    end

    assert_redirected_to preview_push_path(other_push)
  end

  test "an expired push cannot be dispatched" do
    sign_in @luca
    push = Push.create!(kind: "text", payload: "gone", user: @luca)
    push.expire!

    assert_no_difference("PushDispatch.count") do
      post dispatch_push_path(push), params: {dispatch_emails: "alice@example.com"}
    end

    assert_redirected_to preview_push_path(push)
  end

  # -- audit page -----------------------------------------------------------

  test "the audit page lists the delivery log with masked destinations" do
    sign_in @luca
    push = Push.create!(kind: "text", payload: "audited", user: @luca)
    PushDispatch.create!(push: push, channel: :email, role: :supervisor,
      destination: "alexander@example.com", status: :sent, sent_at: Time.current)

    get audit_push_path(push)

    assert_response :success
    assert_includes response.body, "al*******@example.com"
    assert_not_includes response.body, "alexander@example.com"
  end
end
