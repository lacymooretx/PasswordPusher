# frozen_string_literal: true

class TeamsNotificationJob < ApplicationJob
  queue_as :default
  retry_on TeamsNotifier::Error, wait: 30.seconds, attempts: 3

  def perform(push_id, event, details = {})
    return unless Settings.respond_to?(:enable_teams_notifications) && Settings.enable_teams_notifications

    push = Push.find_by(id: push_id)
    return unless push

    TeamsNotifier.new.notify(event, push, details.symbolize_keys)
  end
end
