# frozen_string_literal: true

class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: -> {
    if Settings.respond_to?(:webhooks) && Settings.webhooks.respond_to?(:retry_attempts)
      Settings.webhooks.retry_attempts
    else
      5
    end
  }

  discard_on ActiveRecord::RecordNotFound

  def perform(webhook_id, event, payload)
    webhook = Webhook.find(webhook_id)
    return unless webhook.enabled?

    payload_json = payload.to_json
    signature = webhook.sign_payload(payload_json)

    response = make_request(webhook.url, payload_json, event, signature)

    webhook.webhook_deliveries.create!(
      event: event,
      payload: payload,
      response_code: response[:code],
      response_body: response[:body].to_s[0, 1000],
      success: response[:success],
      attempt: executions + 1
    )

    if response[:success]
      webhook.record_success!
    else
      webhook.record_failure!(response[:error] || "HTTP #{response[:code]}")
      raise StandardError, "Webhook delivery failed: HTTP #{response[:code]}" unless response[:code]&.between?(400, 499)
    end
  end

  private

  def make_request(url, payload_json, event, signature)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri.path.presence || "/")
    request["Content-Type"] = "application/json"
    request["X-PWPush-Signature"] = "sha256=#{signature}"
    request["X-PWPush-Event"] = event
    request["User-Agent"] = "PasswordPusher-Webhook/1.0"
    request.body = payload_json

    response = http.request(request)
    {code: response.code.to_i, body: response.body, success: response.code.to_i.between?(200, 299)}
  rescue => e
    {code: nil, body: nil, success: false, error: e.message}
  end
end
