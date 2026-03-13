# frozen_string_literal: true

# Sends push event notifications to a Microsoft Teams channel
# via an Incoming Webhook connector URL.
#
# Required settings:
#   Settings.teams.webhook_url - The Teams Incoming Webhook URL
#
class TeamsNotifier
  class Error < StandardError; end

  COLORS = {
    "push.created" => "0076D7",
    "push.viewed" => "28A745",
    "push.expired" => "FFC107",
    "push.failed_passphrase" => "DC3545"
  }.freeze

  def initialize(webhook_url = nil)
    @webhook_url = webhook_url || ENV["PWP__TEAMS__WEBHOOK_URL"] ||
      (Settings.respond_to?(:teams) && Settings.teams.respond_to?(:webhook_url) ? Settings.teams.webhook_url : nil)
  end

  def notify(event, push, details = {})
    return unless @webhook_url.present?

    payload = build_card(event, push, details)
    post_to_teams(payload)
  end

  private

  def build_card(event, push, details)
    color = COLORS[event] || "808080"
    app_url = Settings.override_base_url || "https://pwpush.com"
    kind_label = push.kind.capitalize

    facts = [
      {name: "Kind", value: kind_label},
      {name: "Event", value: event},
      {name: "Created By", value: push.user&.email || "Anonymous"}
    ]
    facts << {name: "Days Remaining", value: push.days_remaining.to_s} unless push.expired?
    facts << {name: "Views Remaining", value: push.views_remaining.to_s} unless push.expired?
    facts << {name: "IP", value: details[:ip]} if details[:ip].present?

    {
      "@type" => "MessageCard",
      "@context" => "http://schema.org/extensions",
      "themeColor" => color,
      "summary" => "#{Settings.brand.title}: #{event}",
      "sections" => [{
        "activityTitle" => "#{Settings.brand.title} — #{event_title(event)}",
        "activitySubtitle" => push.name.present? ? push.name : "Push ##{push.url_token&.first(8)}...",
        "facts" => facts,
        "markdown" => true
      }],
      "potentialAction" => [{
        "@type" => "OpenUri",
        "name" => "View in Dashboard",
        "targets" => [{
          "os" => "default",
          "uri" => "#{app_url}/pushes"
        }]
      }]
    }
  end

  def event_title(event)
    case event
    when "push.created" then "New Push Created"
    when "push.viewed" then "Push Viewed"
    when "push.expired" then "Push Expired"
    when "push.failed_passphrase" then "Failed Passphrase Attempt"
    else event.humanize
    end
  end

  def post_to_teams(payload)
    uri = URI(@webhook_url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.open_timeout = 5
      http.read_timeout = 10
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Teams webhook failed: #{response.code} #{response.body&.truncate(200)}"
    end

    true
  end
end
