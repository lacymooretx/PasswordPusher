# frozen_string_literal: true

class WebhookDeliveryCleanupJob < ApplicationJob
  queue_as :default

  def perform
    return unless Settings.respond_to?(:enable_webhooks) && Settings.enable_webhooks

    retention_days = Settings.webhooks.delivery_retention_days
    WebhookDelivery.where("created_at < ?", retention_days.days.ago).in_batches.delete_all
  end
end
