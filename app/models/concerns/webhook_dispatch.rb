# frozen_string_literal: true

module WebhookDispatch
  extend ActiveSupport::Concern

  class_methods do
    def dispatch_webhook(event, push, extra = {})
      return unless Settings.respond_to?(:enable_webhooks) && Settings.enable_webhooks
      return unless push.user_id.present?

      webhooks = Webhook.where(user_id: push.user_id).enabled
      webhooks.each do |webhook|
        events_list = webhook.events
        events_list = JSON.parse(events_list) if events_list.is_a?(String)
        next unless Array(events_list).include?(event)

        payload = build_webhook_payload(event, push, extra)
        WebhookDeliveryJob.perform_later(webhook.id, event, payload)
      end

      # Also dispatch to Teams if enabled
      if Settings.respond_to?(:enable_teams_notifications) && Settings.enable_teams_notifications
        TeamsNotificationJob.perform_later(push.id, event, extra)
      end
    end

    private

    def build_webhook_payload(event, push, extra)
      {
        event: event,
        timestamp: Time.current.iso8601,
        push: {
          url_token: push.url_token,
          kind: push.kind,
          expired: push.expired?,
          created_at: push.created_at&.iso8601,
          expire_after_days: push.expire_after_days,
          expire_after_views: push.expire_after_views
        }.merge(extra)
      }
    end
  end
end
