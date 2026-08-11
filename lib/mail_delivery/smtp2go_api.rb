# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "uri"

module MailDelivery
  # ActionMailer delivery method that sends through the SMTP2GO HTTP API
  # (POST https://api.smtp2go.com/v3/email/send) instead of SMTP.
  #
  # Registered as +:smtp2go_api+ in config/initializers/smtp2go_api.rb. Select it
  # with:
  #
  #   PWP__MAIL__DELIVERY_METHOD=smtp2go_api
  #   PWP__MAIL__SMTP2GO_API_KEY=api-xxxxxxxx
  #
  # Configuration is read from +Settings.mail+ at delivery time rather than
  # frozen into ActionMailer's +*_settings+ hash, so a SettingOverride applied
  # at runtime takes effect without a restart.
  #
  # A SMTP2GO 200 response can still describe a failed send (+data.failed > 0+),
  # so both the HTTP status and the response body are checked. Failures raise
  # DeliveryError, which ActionMailer surfaces when +raise_delivery_errors+ is
  # on and swallows when it is off -- same contract as the SMTP delivery method.
  class Smtp2goApi
    class DeliveryError < StandardError; end

    DEFAULT_API_URL = "https://api.smtp2go.com/v3/email/send"
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_READ_TIMEOUT = 15

    # Headers SMTP2GO derives from the structured fields, or that belong to the
    # transport it builds itself. Everything else is forwarded verbatim so
    # RFC 5322 threading (Message-Id / In-Reply-To / References) survives.
    RESERVED_HEADERS = %w[
      from to cc bcc subject date mime-version
      content-type content-transfer-encoding content-disposition content-id
    ].freeze

    attr_accessor :settings

    def initialize(values = {})
      @settings = (values || {}).symbolize_keys
    end

    def deliver!(mail)
      key = api_key
      if key.blank?
        raise DeliveryError,
          "SMTP2GO API delivery is selected but no API key is configured. " \
          "Set PWP__MAIL__SMTP2GO_API_KEY (or mail.smtp2go_api_key in settings.yml)."
      end

      response = post(build_payload(mail), key)
      verify!(response)
      response
    end

    # -- payload ------------------------------------------------------------

    def build_payload(mail)
      payload = {
        "sender" => sender_for(mail),
        "to" => addresses(mail, :to),
        "subject" => mail.subject.to_s
      }

      cc = addresses(mail, :cc)
      bcc = addresses(mail, :bcc)
      payload["cc"] = cc if cc.any?
      payload["bcc"] = bcc if bcc.any?

      html_body, text_body = bodies(mail)
      payload["html_body"] = html_body if html_body.present?
      payload["text_body"] = text_body if text_body.present?

      attachments, inlines = attachment_parts(mail)
      payload["attachments"] = attachments if attachments.any?
      payload["inlines"] = inlines if inlines.any?

      headers = custom_headers(mail)
      payload["custom_headers"] = headers if headers.any?

      if payload["to"].empty?
        raise DeliveryError, "Cannot deliver a message with no To: recipients."
      end

      payload
    end

    private

    # -- configuration ------------------------------------------------------

    def api_key
      settings[:api_key].presence || setting(:smtp2go_api_key)
    end

    def api_url
      settings[:api_url].presence || setting(:smtp2go_api_url).presence || DEFAULT_API_URL
    end

    def open_timeout
      (settings[:open_timeout] || setting(:smtp2go_open_timeout) || DEFAULT_OPEN_TIMEOUT).to_i
    end

    def read_timeout
      (settings[:read_timeout] || setting(:smtp2go_read_timeout) || DEFAULT_READ_TIMEOUT).to_i
    end

    def setting(key)
      return nil unless defined?(Settings) && Settings.respond_to?(:mail) && Settings.mail
      Settings.mail.respond_to?(key) ? Settings.mail.public_send(key) : nil
    end

    # -- message decomposition ----------------------------------------------

    # SMTP2GO takes a single sender string; keep the display name when present.
    def sender_for(mail)
      formatted(mail, :from).first || setting(:mailer_sender).to_s
    end

    def addresses(mail, field)
      formatted(mail, field)
    end

    # Mail::Field#formatted preserves `"Name" <addr>`; fall back to the bare
    # address list for any field type that does not implement it.
    def formatted(mail, field)
      header = mail[field]
      return [] if header.nil?

      values = if header.respond_to?(:formatted)
        header.formatted
      else
        mail.public_send(field)
      end
      Array(values).map(&:to_s).reject(&:blank?)
    rescue NoMethodError
      Array(mail.public_send(field)).map(&:to_s).reject(&:blank?)
    end

    def bodies(mail)
      if mail.multipart?
        html = mail.html_part&.decoded
        text = mail.text_part&.decoded
        # A multipart/mixed message whose only body part is unlabelled (no
        # alternative wrapper) leaves both nil -- fall back to the first
        # non-attachment part rather than dropping the body on the floor.
        if html.blank? && text.blank?
          part = mail.all_parts.find { |p| !p.attachment? && p.body.present? }
          if part
            (part.mime_type == "text/html") ? html = part.decoded : text = part.decoded
          end
        end
        [html, text]
      elsif mail.mime_type == "text/html"
        [mail.body.decoded, nil]
      else
        [nil, mail.body.decoded]
      end
    end

    def attachment_parts(mail)
      attachments = []
      inlines = []

      mail.attachments.each do |part|
        entry = {
          "filename" => part.filename.to_s,
          "fileblob" => Base64.strict_encode64(part.body.decoded),
          "mimetype" => part.mime_type.to_s
        }

        if part.inline?
          # `cid:` references in the HTML body resolve against this value.
          entry["cid"] = part.cid.to_s
          inlines << entry
        else
          attachments << entry
        end
      end

      [attachments, inlines]
    end

    def custom_headers(mail)
      mail.header.fields.filter_map do |field|
        name = field.name.to_s
        next if RESERVED_HEADERS.include?(name.downcase)

        value = field.value.to_s
        next if value.blank?

        {"header" => name, "value" => value}
      end
    end

    # -- transport ----------------------------------------------------------

    def post(payload, key)
      uri = URI.parse(api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["X-Smtp2go-Api-Key"] = key
      request.body = JSON.generate(payload)

      http.request(request)
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError => e
      raise DeliveryError, "SMTP2GO API request failed: #{e.class}: #{e.message}"
    end

    def verify!(response)
      code = response.code.to_i
      body = parse_body(response.body)

      unless (200..299).cover?(code)
        raise DeliveryError, "SMTP2GO API returned HTTP #{code}: #{error_detail(body, response.body)}"
      end

      data = body.is_a?(Hash) ? body["data"] : nil
      failed = data.is_a?(Hash) ? data["failed"].to_i : 0
      return if failed.zero?

      failures = data["failures"]
      raise DeliveryError,
        "SMTP2GO API rejected #{failed} recipient(s): #{Array(failures).join("; ").presence || "no detail given"}"
    end

    def parse_body(raw)
      JSON.parse(raw.to_s)
    rescue JSON::ParserError
      nil
    end

    def error_detail(parsed, raw)
      if parsed.is_a?(Hash)
        detail = parsed["error"] || parsed["error_code"] || parsed.dig("data", "error")
        return detail.to_s if detail.present?
      end
      raw.to_s[0, 500]
    end
  end
end
