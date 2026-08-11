# frozen_string_literal: true

# A single outbound delivery of a push's secret link.
#
# Created up-front in the +pending+ state by PushDispatcher so that a link the
# operator asked to send is recorded even if the provider call later fails; the
# delivery job flips each row to +sent+ or +failed+.
#
# +destination+ (an email address or E.164 mobile number) is recipient PII and
# is encrypted at rest, so it cannot be queried directly -- look rows up through
# the owning push.
class PushDispatch < ApplicationRecord
  belongs_to :push, optional: true

  enum :channel, {email: 0, sms: 1}, validate: true
  enum :role, {recipient: 0, supervisor: 1}, validate: true
  enum :status, {pending: 0, sent: 1, failed: 2}, validate: true

  has_encrypted :destination

  validates :destination, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  def mark_sent!(provider_message_id = nil)
    update!(status: :sent, sent_at: Time.current, provider_message_id: provider_message_id, error: nil)
  end

  # Error text is truncated because provider bodies can be long and this column
  # is surfaced in the UI and API.
  def mark_failed!(message)
    update!(status: :failed, error: message.to_s[0, 500])
  end

  # Destinations are shown back to the push owner in the dashboard and audit
  # views; mask them so a shoulder-surfer or a screenshot does not leak a full
  # address or phone number.
  def masked_destination
    value = destination.to_s
    return value if value.blank?

    if email?
      local, _, domain = value.partition("@")
      return value if domain.blank?
      "#{local[0, 2]}#{"*" * [local.length - 2, 1].max}@#{domain}"
    else
      "#{"*" * [value.length - 4, 0].max}#{value[-4..]}"
    end
  end
end
