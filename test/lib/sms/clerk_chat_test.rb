# frozen_string_literal: true

require "test_helper"

class Sms::ClerkChatTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body)

  class FakeHttp
    attr_accessor :use_ssl, :open_timeout, :read_timeout
    attr_reader :last_request

    def initialize(response)
      @response = response
    end

    def request(req)
      @last_request = req
      @response
    end
  end

  setup do
    @client = Sms::ClerkChat.new(api_key: "ck-test", sender: "+12819414028", sent_by_name: "Password Pusher")
  end

  # The real 201 shape, captured from a live send on 2026-08-11.
  def created_response
    FakeResponse.new(
      "201",
      {
        data: {
          id: 79999924,
          status: "sent",
          error: nil,
          errorCode: nil,
          segments: 1,
          sender: "+12819414028",
          recipients: ["+17138750817"]
        },
        links: {self: "/public/messages"}
      }.to_json
    )
  end

  def deliver_with(response, to: "+17138750817", body: "hello")
    http = FakeHttp.new(response)
    result = nil
    Net::HTTP.stub :new, http do
      result = @client.deliver(to: to, body: body)
    end
    [result, http.last_request]
  end

  test "posts the Clerk Chat message shape with the apiKey header" do
    _result, request = deliver_with(created_response)

    assert_equal "ck-test", request["apiKey"]
    assert_equal "application/json", request["Content-Type"]

    payload = JSON.parse(request.body)
    assert_equal "+12819414028", payload["sender"]
    assert_equal ["+17138750817"], payload["recipients"]
    assert_equal "hello", payload["body"]
    assert_equal [], payload["mediaUrls"]
    assert_equal "Password Pusher", payload["sentByName"]
  end

  test "returns the provider message id from the data envelope" do
    result, _request = deliver_with(created_response)

    assert_equal "79999924", result.message_id
    assert_equal "sent", result.status
  end

  # Older/flat response shape — keep working if Clerk changes it back.
  test "also reads a flat response body" do
    response = FakeResponse.new("201", {id: "msg_abc123", status: "queued"}.to_json)

    result, _request = deliver_with(response)

    assert_equal "msg_abc123", result.message_id
    assert_equal "queued", result.status
  end

  # Clerk can accept the request and still reject the message.
  test "raises when a 201 body reports a rejected message" do
    response = FakeResponse.new(
      "201",
      {data: {id: 1, status: "failed", error: "Unreachable carrier"}}.to_json
    )

    error = assert_raises(Sms::ClerkChat::DeliveryError) { deliver_with(response) }
    assert_match(/rejected the message/, error.message)
    assert_match(/Unreachable carrier/, error.message)
  end

  test "raises when a 201 body carries only an error code" do
    response = FakeResponse.new(
      "201",
      {data: {id: 1, status: "sent", errorCode: "INVALID_SENDER"}}.to_json
    )

    error = assert_raises(Sms::ClerkChat::DeliveryError) { deliver_with(response) }
    assert_match(/INVALID_SENDER/, error.message)
  end

  test "raises on a non-2xx response with the provider error text" do
    response = FakeResponse.new("400", {error: "Invalid sender number", code: "INVALID_SENDER"}.to_json)

    error = assert_raises(Sms::ClerkChat::DeliveryError) { deliver_with(response) }
    assert_match(/HTTP 400/, error.message)
    assert_match(/Invalid sender number/, error.message)
  end

  test "raises when the recipient or body is blank" do
    assert_raises(Sms::ClerkChat::DeliveryError) { @client.deliver(to: "", body: "hi") }
    assert_raises(Sms::ClerkChat::DeliveryError) { @client.deliver(to: "+17138750817", body: "") }
  end

  test "raises when no api key is configured" do
    client = Sms::ClerkChat.new(sender: "+12819414028")

    error = assert_raises(Sms::ClerkChat::DeliveryError) { client.deliver(to: "+17138750817", body: "hi") }
    assert_match(/API key is not configured/, error.message)
  end

  test "raises when no sender number is configured" do
    client = Sms::ClerkChat.new(api_key: "ck-test")

    error = assert_raises(Sms::ClerkChat::DeliveryError) { client.deliver(to: "+17138750817", body: "hi") }
    assert_match(/sender number is not configured/, error.message)
  end

  # Regression: the Config gem YAML-parses env vars, so
  # PWP__CLERK_CHAT__SENDER='+12819414028' reaches us as the Integer
  # 12819414028. Sending that as a number made Clerk Chat answer 422.
  test "normalizes an integer sender back into an E.164 string" do
    client = Sms::ClerkChat.new(api_key: "ck-test", sender: 12819414028)

    http = FakeHttp.new(created_response)
    Net::HTTP.stub :new, http do
      client.deliver(to: "+17138750817", body: "hi")
    end

    payload = JSON.parse(http.last_request.body)
    assert_equal "+12819414028", payload["sender"]
    assert_kind_of String, payload["sender"]
  end

  test "normalizes a loosely formatted sender" do
    client = Sms::ClerkChat.new(api_key: "ck-test", sender: "(281) 941-4028")

    http = FakeHttp.new(created_response)
    Net::HTTP.stub :new, http do
      client.deliver(to: "+17138750817", body: "hi")
    end

    assert_equal "+12819414028", JSON.parse(http.last_request.body)["sender"]
  end

  test "configured? reflects key and sender presence" do
    assert Sms::ClerkChat.new(api_key: "k", sender: "+1555").configured?
    assert_not Sms::ClerkChat.new(api_key: "k").configured?
    assert_not Sms::ClerkChat.new(sender: "+1555").configured?
  end
end
