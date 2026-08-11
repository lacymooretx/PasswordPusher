# frozen_string_literal: true

require "test_helper"

class MailDelivery::Smtp2goApiTest < ActiveSupport::TestCase
  # Minimal Net::HTTPResponse stand-in -- Net::HTTPResponse's own constructor
  # is awkward to drive and we only read #code and #body.
  FakeResponse = Struct.new(:code, :body)

  # Captures the request instead of putting it on the wire.
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

  # Stands in for a host that refuses the connection.
  class RefusingHttp
    attr_accessor :use_ssl, :open_timeout, :read_timeout

    def request(_req)
      raise Errno::ECONNREFUSED
    end
  end

  setup do
    @delivery = MailDelivery::Smtp2goApi.new(api_key: "api-testkey")
  end

  def deliver_with(response, delivery: @delivery, mail: simple_mail)
    http = FakeHttp.new(response)
    result = nil
    Net::HTTP.stub :new, http do
      result = delivery.deliver!(mail)
    end
    [result, http.last_request]
  end

  def ok_response(succeeded: 1, failed: 0, failures: [])
    FakeResponse.new(
      "200",
      {request_id: "req-1", data: {succeeded: succeeded, failed: failed, failures: failures, email_id: "abc"}}.to_json
    )
  end

  def simple_mail
    Mail.new do
      from '"Aspendora Help Desk" <help@aspendora.com>'
      to '"Ken Miller" <ken@example.com>'
      subject "Hello"
      body "plain text body"
    end
  end

  # -- payload construction -------------------------------------------------

  test "builds a payload with formatted sender and recipients" do
    payload = @delivery.build_payload(simple_mail)

    assert_equal "Aspendora Help Desk <help@aspendora.com>", payload["sender"]
    assert_equal ["Ken Miller <ken@example.com>"], payload["to"]
    assert_equal "Hello", payload["subject"]
    assert_equal "plain text body", payload["text_body"]
    assert_nil payload["html_body"]
  end

  test "includes cc and bcc only when present" do
    mail = simple_mail
    assert_nil @delivery.build_payload(mail)["cc"]

    mail.cc = "cc@example.com"
    mail.bcc = "bcc@example.com"
    payload = @delivery.build_payload(mail)

    assert_equal ["cc@example.com"], payload["cc"]
    assert_equal ["bcc@example.com"], payload["bcc"]
  end

  test "splits html and text parts of a multipart message" do
    mail = Mail.new do
      from "a@example.com"
      to "b@example.com"
      subject "Multipart"
      text_part { body "text version" }
      html_part do
        content_type "text/html; charset=UTF-8"
        body "<h1>html version</h1>"
      end
    end

    payload = @delivery.build_payload(mail)

    assert_equal "text version", payload["text_body"]
    assert_equal "<h1>html version</h1>", payload["html_body"]
  end

  test "sends a single html message as html_body" do
    mail = Mail.new do
      from "a@example.com"
      to "b@example.com"
      subject "HTML only"
      content_type "text/html; charset=UTF-8"
      body "<p>hi</p>"
    end

    payload = @delivery.build_payload(mail)

    assert_equal "<p>hi</p>", payload["html_body"]
    assert_nil payload["text_body"]
  end

  test "separates inline images from regular attachments" do
    mail = Mail.new do
      from "a@example.com"
      to "b@example.com"
      subject "With attachments"
      html_part do
        content_type "text/html; charset=UTF-8"
        body "<img src='cid:logo.png'>"
      end
    end
    mail.attachments.inline["logo.png"] = "PNGDATA"
    mail.attachments["report.pdf"] = "PDFDATA"

    payload = @delivery.build_payload(mail)

    assert_equal 1, payload["inlines"].size
    assert_equal "logo.png", payload["inlines"].first["filename"]
    assert_equal "PNGDATA", Base64.decode64(payload["inlines"].first["fileblob"])
    assert payload["inlines"].first["cid"].present?, "inline part must carry a cid"

    assert_equal 1, payload["attachments"].size
    assert_equal "report.pdf", payload["attachments"].first["filename"]
    assert_equal "PDFDATA", Base64.decode64(payload["attachments"].first["fileblob"])
  end

  test "forwards threading headers and drops headers SMTP2GO derives itself" do
    mail = simple_mail
    mail.header["Message-ID"] = "<abc@pwpush.aspendora.com>"
    mail.header["In-Reply-To"] = "<xyz@example.com>"
    mail.header["X-Pwpush-Kind"] = "text"

    headers = @delivery.build_payload(mail)["custom_headers"]
    names = headers.map { |h| h["header"] }

    assert_includes names, "Message-ID"
    assert_includes names, "In-Reply-To"
    assert_includes names, "X-Pwpush-Kind"
    assert_not_includes names.map(&:downcase), "to"
    assert_not_includes names.map(&:downcase), "from"
    assert_not_includes names.map(&:downcase), "subject"
  end

  test "refuses to deliver a message with no recipients" do
    mail = Mail.new do
      from "a@example.com"
      subject "Nobody"
      body "hi"
    end

    error = assert_raises(MailDelivery::Smtp2goApi::DeliveryError) { @delivery.build_payload(mail) }
    assert_match(/no To: recipients/, error.message)
  end

  # -- transport ------------------------------------------------------------

  test "posts to the SMTP2GO endpoint with the api key header" do
    _result, request = deliver_with(ok_response)

    assert_equal "application/json", request["Content-Type"]
    assert_equal "api-testkey", request["X-Smtp2go-Api-Key"]

    body = JSON.parse(request.body)
    assert_equal "Hello", body["subject"]
  end

  # settings.yml ships smtp2go_api_key commented out, so the test environment
  # has no key unless PWP__MAIL__SMTP2GO_API_KEY is exported (test_helper strips
  # all PWP__ vars). Selecting the transport without a key must fail loudly
  # rather than silently dropping mail.
  test "raises when no api key is configured" do
    delivery = MailDelivery::Smtp2goApi.new

    error = assert_raises(MailDelivery::Smtp2goApi::DeliveryError) { delivery.deliver!(simple_mail) }
    assert_match(/no API key is configured/, error.message)
  end

  test "raises on a non-2xx response and surfaces the API error text" do
    response = FakeResponse.new("401", {error: "Bad API key", error_code: "E_ApiResponseCodes.AUTH"}.to_json)

    error = assert_raises(MailDelivery::Smtp2goApi::DeliveryError) { deliver_with(response) }
    assert_match(/HTTP 401/, error.message)
    assert_match(/Bad API key/, error.message)
  end

  # A 200 with data.failed > 0 is SMTP2GO's per-recipient rejection shape.
  test "raises when a 200 response reports failed recipients" do
    response = ok_response(succeeded: 0, failed: 1, failures: ["ken@example.com: rejected by remote"])

    error = assert_raises(MailDelivery::Smtp2goApi::DeliveryError) { deliver_with(response) }
    assert_match(/rejected 1 recipient/, error.message)
    assert_match(/rejected by remote/, error.message)
  end

  test "wraps network failures in DeliveryError" do
    raising = RefusingHttp.new

    Net::HTTP.stub :new, raising do
      error = assert_raises(MailDelivery::Smtp2goApi::DeliveryError) { @delivery.deliver!(simple_mail) }
      assert_match(/SMTP2GO API request failed/, error.message)
    end
  end

  test "returns the response on success" do
    result, _request = deliver_with(ok_response)
    assert_equal "200", result.code
  end

  # -- ActionMailer registration -------------------------------------------

  test "is registered with ActionMailer as :smtp2go_api" do
    assert_equal MailDelivery::Smtp2goApi, ActionMailer::Base.delivery_methods[:smtp2go_api]
  end
end
