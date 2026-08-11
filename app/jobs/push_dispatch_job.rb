# frozen_string_literal: true

# Performs one queued delivery of a secret link (email or SMS) and records the
# outcome on the PushDispatch row.
#
# Email is delivered with deliver_now rather than deliver_later: this job *is*
# the async step, and delivering inline is what lets us catch a provider failure
# and mark the row +failed+ instead of reporting a false success.
class PushDispatchJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(dispatch_id, secret_url)
    dispatch = PushDispatch.find_by(id: dispatch_id)
    return unless dispatch

    push = dispatch.push
    return dispatch.mark_failed!("Push no longer exists.") if push.nil?

    unless Settings.respond_to?(:enable_auto_dispatch) && Settings.enable_auto_dispatch
      return dispatch.mark_failed!("Auto dispatch is disabled.")
    end

    case dispatch.channel.to_sym
    when :email
      deliver_email(dispatch, push, secret_url)
    when :sms
      deliver_sms(dispatch, push, secret_url)
    else
      dispatch.mark_failed!("Unknown dispatch channel: #{dispatch.channel}")
    end
  end

  private

  def deliver_email(dispatch, push, secret_url)
    delivery = PushMailer.push_dispatched(push, secret_url, dispatch.destination, role: dispatch.role)

    # Settings.mail.raise_delivery_errors is false by default, which would let a
    # rejected send look successful. Force it on for this message only so the
    # failure reaches the rescue below and lands on the dispatch row.
    message = delivery.message
    message.raise_delivery_errors = true
    message.deliver

    dispatch.mark_sent!(message.message_id)
  rescue => e
    Rails.logger.error("PushDispatchJob email failure (dispatch #{dispatch.id}): #{e.class}: #{e.message}")
    dispatch.mark_failed!("#{e.class}: #{e.message}")
  end

  def deliver_sms(dispatch, push, secret_url)
    unless Settings.respond_to?(:enable_sms_dispatch) && Settings.enable_sms_dispatch
      return dispatch.mark_failed!("SMS dispatch is disabled.")
    end

    body = PushDispatcher.sms_body(push, secret_url, role: dispatch.role)
    result = Sms::ClerkChat.new.deliver(to: dispatch.destination, body: body)

    dispatch.mark_sent!(result.message_id)
  rescue => e
    Rails.logger.error("PushDispatchJob SMS failure (dispatch #{dispatch.id}): #{e.class}: #{e.message}")
    dispatch.mark_failed!("#{e.class}: #{e.message}")
  end
end
