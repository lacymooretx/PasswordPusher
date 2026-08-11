# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Sms
  # Clerk Chat SMS transport.
  #
  #   POST https://web-api.clerk.chat/public/messages
  #   apiKey: <key>
  #   {"sender": "+1...", "recipients": ["+1..."], "body": "...", "mediaUrls": []}
  #
  # One recipient per call: Clerk accepts an array, but a single failing number
  # in a batch would leave us unable to attribute the failure to a specific
  # PushDispatch row.
  class ClerkChat
    class DeliveryError < StandardError; end

    DEFAULT_API_URL = "https://web-api.clerk.chat/public/messages"
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_READ_TIMEOUT = 15

    Result = Struct.new(:message_id, :status, keyword_init: true)

    def initialize(settings = {})
      @settings = (settings || {}).symbolize_keys
    end

    def self.configured?
      new.configured?
    end

    def configured?
      api_key.present? && sender.present?
    end

    # Returns a Result on success; raises DeliveryError otherwise.
    def deliver(to:, body:)
      raise DeliveryError, "SMS recipient is blank." if to.blank?
      raise DeliveryError, "SMS body is blank." if body.blank?

      unless api_key.present?
        raise DeliveryError,
          "Clerk Chat API key is not configured. Set PWP__CLERK_CHAT__API_KEY."
      end
      unless sender.present?
        raise DeliveryError,
          "Clerk Chat sender number is not configured. Set PWP__CLERK_CHAT__SENDER."
      end

      payload = {
        "sender" => sender,
        "recipients" => [to],
        "body" => body,
        "mediaUrls" => []
      }
      payload["sentByName"] = sent_by_name if sent_by_name.present?

      response = post(payload)
      parse!(response)
    end

    private

    attr_reader :settings

    def api_key
      settings[:api_key].presence || setting(:api_key)
    end

    # Always an E.164 *string*.
    #
    # The Config gem YAML-parses environment variables, so
    # PWP__CLERK_CHAT__SENDER='+12819414028' arrives as the Integer
    # 12819414028 (YAML reads a leading "+" as an explicit-sign integer).
    # Serialising that into the request body sends a number where Clerk Chat
    # requires a string, and it answers 422 with no detail. Normalising
    # whatever we are handed fixes it regardless of how the value was supplied.
    def sender
      raw = settings[:sender].presence || setting(:sender)
      return nil if raw.blank?

      Sms::PhoneNumber.normalize(raw.to_s) || raw.to_s
    end

    def sent_by_name
      settings[:sent_by_name].presence || setting(:sent_by_name)
    end

    def api_url
      settings[:api_url].presence || setting(:api_url).presence || DEFAULT_API_URL
    end

    def open_timeout
      (settings[:open_timeout] || setting(:open_timeout) || DEFAULT_OPEN_TIMEOUT).to_i
    end

    def read_timeout
      (settings[:read_timeout] || setting(:read_timeout) || DEFAULT_READ_TIMEOUT).to_i
    end

    def setting(key)
      return nil unless defined?(Settings) && Settings.respond_to?(:clerk_chat) && Settings.clerk_chat
      Settings.clerk_chat.respond_to?(key) ? Settings.clerk_chat.public_send(key) : nil
    end

    def post(payload)
      uri = URI.parse(api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["apiKey"] = api_key
      request.body = JSON.generate(payload)

      http.request(request)
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError => e
      raise DeliveryError, "Clerk Chat request failed: #{e.class}: #{e.message}"
    end

    def parse!(response)
      code = response.code.to_i
      body = begin
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        nil
      end

      unless (200..299).cover?(code)
        detail = if body.is_a?(Hash)
          body["error"] || body["message"] || body["code"]
        end
        raise DeliveryError, "Clerk Chat returned HTTP #{code}: #{detail.presence || response.body.to_s[0, 300]}"
      end

      # Verified live 2026-08-11: a 201 wraps the message in a "data" object --
      # {"data": {"id": 79999924, "status": "sent", "error": null, ...}}.
      # (clerk-chat-api/send-message.md documented a flat body; it was wrong.)
      # Fall back to the flat shape so either form works.
      message = body["data"] if body.is_a?(Hash) && body["data"].is_a?(Hash)
      message ||= body if body.is_a?(Hash)
      message ||= {}

      status = message["status"]
      error = message["error"].presence || message["errorCode"].presence

      # Clerk can accept the request and still reject the message. Treat that as
      # a failure so the dispatch row records it rather than claiming success.
      if error.present? || %w[failed undelivered rejected].include?(status.to_s)
        raise DeliveryError,
          "Clerk Chat rejected the message (status: #{status.presence || "unknown"}): " \
          "#{error.presence || "no detail given"}"
      end

      Result.new(
        message_id: (message["id"] || message["messageId"])&.to_s,
        status: status
      )
    end
  end
end
