# frozen_string_literal: true

require "test_helper"

# Covers the dispatch surface on both /p (v1) and /api/v2/pushes: inline
# dispatch on create, the standalone dispatch endpoint, and the delivery log.
class ApiDispatchTest < ActionDispatch::IntegrationTest
  setup do
    @original_enable_logins = Settings.enable_logins
    @original_auto_dispatch = Settings.enable_auto_dispatch
    @original_sms_dispatch = Settings.enable_sms_dispatch
    @original_dispatch_config = Settings.auto_dispatch

    Settings.enable_logins = true
    Settings.enable_auto_dispatch = true
    Settings.enable_sms_dispatch = true
    Settings.auto_dispatch = Config::Options.new(
      max_recipients: 10, max_sms_recipients: 5, enable_supervisor: true
    )

    @user = users(:luca)
    @push = Push.create!(kind: "text", payload: "dispatch-me", user: @user)
  end

  teardown do
    Settings.enable_logins = @original_enable_logins
    Settings.enable_auto_dispatch = @original_auto_dispatch
    Settings.enable_sms_dispatch = @original_sms_dispatch
    Settings.auto_dispatch = @original_dispatch_config
  end

  def auth_headers(user = @user)
    {"X-User-Email" => user.email, "X-User-Token" => user.authentication_token}
  end

  def json
    JSON.parse(response.body)
  end

  # -- standalone dispatch endpoint ---------------------------------------

  test "dispatches to recipients and a supervisor over both channels" do
    assert_difference("PushDispatch.count", 4) do
      post "/p/#{@push.url_token}/dispatch.json",
        params: {
          dispatch: {
            emails: ["alice@example.com", "bob@example.com"],
            phones: ["713-875-0817"],
            supervisor_email: "boss@example.com"
          }
        },
        headers: auth_headers, as: :json
    end

    assert_response :created
    assert_equal 4, json["queued"]
    assert_empty json["errors"]

    roles = json["dispatches"].map { |d| [d["channel"], d["role"]] }
    assert_includes roles, ["email", "recipient"]
    assert_includes roles, ["sms", "recipient"]
    assert_includes roles, ["email", "supervisor"]
  end

  test "accepts comma separated strings as well as arrays" do
    post "/p/#{@push.url_token}/dispatch.json",
      params: {dispatch: {emails: "alice@example.com, bob@example.com"}},
      headers: auth_headers, as: :json

    assert_response :created
    assert_equal 2, json["queued"]
  end

  # Destinations are PII; the API must never echo them back in full.
  test "masks destinations in the response" do
    post "/p/#{@push.url_token}/dispatch.json",
      params: {dispatch: {emails: ["alexander@example.com"]}},
      headers: auth_headers, as: :json

    assert_response :created
    destination = json["dispatches"].first["destination"]
    assert_equal "al*******@example.com", destination
    assert_not_includes response.body, "alexander@example.com"
  end

  test "reports refused inputs without failing the whole request" do
    post "/p/#{@push.url_token}/dispatch.json",
      params: {dispatch: {emails: ["good@example.com", "bad-address"]}},
      headers: auth_headers, as: :json

    assert_response :created
    assert_equal 1, json["queued"]
    assert(json["errors"].any? { |e| e.include?("bad-address") })
  end

  test "returns 422 when nothing could be dispatched" do
    post "/p/#{@push.url_token}/dispatch.json",
      params: {dispatch: {emails: ["not-an-email"]}},
      headers: auth_headers, as: :json

    assert_response :unprocessable_content
    assert_equal 0, json["queued"]
  end

  test "refuses SMS when the sms flag is off but still dispatches email" do
    Settings.enable_sms_dispatch = false

    post "/p/#{@push.url_token}/dispatch.json",
      params: {dispatch: {emails: ["alice@example.com"], phones: ["713-875-0817"]}},
      headers: auth_headers, as: :json

    assert_response :created
    assert_equal 1, json["queued"]
    assert_includes json["errors"], "SMS dispatch is not enabled."
  end

  test "refuses to dispatch an expired push" do
    @push.expire!

    post "/p/#{@push.url_token}/dispatch.json",
      params: {dispatch: {emails: ["alice@example.com"]}},
      headers: auth_headers, as: :json

    assert_response :unprocessable_content
  end

  # -- authorization --------------------------------------------------------

  test "requires authentication" do
    assert_no_difference("PushDispatch.count") do
      post "/p/#{@push.url_token}/dispatch.json",
        params: {dispatch: {emails: ["alice@example.com"]}}, as: :json
    end

    assert_response :unauthorized
  end

  test "refuses to dispatch a push belonging to another user" do
    other = users(:one)

    assert_no_difference("PushDispatch.count") do
      post "/p/#{@push.url_token}/dispatch.json",
        params: {dispatch: {emails: ["alice@example.com"]}},
        headers: auth_headers(other), as: :json
    end

    assert_response :forbidden
  end

  # -- inline dispatch on create -------------------------------------------

  test "dispatches inline when create carries a dispatch object" do
    assert_difference("PushDispatch.count", 2) do
      post "/p.json",
        params: {
          password: {payload: "inline-secret"},
          dispatch: {emails: ["alice@example.com"], supervisor_email: "boss@example.com"}
        },
        headers: auth_headers, as: :json
    end

    assert_response :created
    assert_equal 2, json["dispatch"]["queued"]
  end

  test "create response omits the dispatch key when none was requested" do
    post "/p.json", params: {password: {payload: "no-dispatch"}}, headers: auth_headers, as: :json

    assert_response :created
    assert_not json.key?("dispatch")
  end

  # An anonymous caller must not be able to make the server email arbitrary
  # addresses on its behalf.
  test "ignores an inline dispatch from an unauthenticated caller" do
    assert_no_difference("PushDispatch.count") do
      post "/p.json",
        params: {password: {payload: "anon"}, dispatch: {emails: ["victim@example.com"]}},
        as: :json
    end

    assert_response :created
  end

  # -- delivery log ---------------------------------------------------------

  test "lists the delivery log with statuses" do
    sent = PushDispatch.create!(push: @push, channel: :email, role: :recipient,
      destination: "alice@example.com", status: :sent, sent_at: Time.current, provider_message_id: "m1")
    PushDispatch.create!(push: @push, channel: :sms, role: :supervisor,
      destination: "+17138750817", status: :failed, error: "Invalid sender number")

    get "/p/#{@push.url_token}/dispatches.json", headers: auth_headers

    assert_response :success
    assert_equal 2, json["dispatches"].size

    first = json["dispatches"].first
    assert_equal sent.id, first["id"]
    assert_equal "sent", first["status"]
    assert_equal "m1", first["provider_message_id"]

    failed = json["dispatches"].last
    assert_equal "failed", failed["status"]
    assert_equal "Invalid sender number", failed["error"]
    assert_equal "********0817", failed["destination"]
  end

  test "delivery log requires ownership" do
    get "/p/#{@push.url_token}/dispatches.json", headers: auth_headers(users(:one))
    assert_response :forbidden
  end

  # -- apiv2 parity ---------------------------------------------------------

  test "apiv2 exposes the same dispatch endpoint" do
    assert_difference("PushDispatch.count", 1) do
      post "/api/v2/pushes/#{@push.url_token}/dispatch",
        params: {dispatch: {emails: ["alice@example.com"]}},
        headers: auth_headers, as: :json
    end

    assert_response :created
  end

  test "apiv2 dispatch requires authentication" do
    post "/api/v2/pushes/#{@push.url_token}/dispatch",
      params: {dispatch: {emails: ["alice@example.com"]}}, as: :json

    assert_response :unauthorized
  end

  test "apiv2 create accepts an inline dispatch object" do
    assert_difference("PushDispatch.count", 1) do
      post "/api/v2/pushes",
        params: {push: {payload: "v2-inline"}, dispatch: {emails: ["alice@example.com"]}},
        headers: auth_headers, as: :json
    end

    assert_response :created
  end
end
