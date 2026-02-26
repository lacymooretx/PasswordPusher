# frozen_string_literal: true

class AutoDispatchJob < ApplicationJob
  queue_as :default

  def perform(push_id, secret_url, emails)
    push = Push.find_by(id: push_id)
    return unless push
    return unless Settings.respond_to?(:enable_auto_dispatch) && Settings.enable_auto_dispatch

    # Enforce max recipients limit
    max = Settings.auto_dispatch.max_recipients
    recipients = emails.first(max)

    recipients.each do |email|
      PushMailer.push_dispatched(push, secret_url, email).deliver_later
    end
  end
end
