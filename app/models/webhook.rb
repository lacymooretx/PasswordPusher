# frozen_string_literal: true

class Webhook < ApplicationRecord
  belongs_to :user

  has_many :webhook_deliveries, dependent: :destroy
  has_encrypted :secret

  VALID_EVENTS = %w[
    push.created
    push.viewed
    push.expired
    push.failed_passphrase
    request.submitted
  ].freeze

  validates :url, presence: true, format: {with: /\Ahttps?:\/\/.+\z/i, message: "must be a valid HTTP(S) URL"}
  validates :events, presence: true
  validate :events_must_be_valid

  before_create :generate_secret

  scope :enabled, -> { where(enabled: true) }
  scope :for_event, ->(event) { enabled.where("events LIKE ?", "%#{event}%") }

  def sign_payload(payload_json)
    OpenSSL::HMAC.hexdigest("sha256", secret, payload_json)
  end

  def record_success!
    update!(failure_count: 0, last_success_at: Time.current)
  end

  def record_failure!(reason)
    new_count = failure_count + 1
    max_failures = if Settings.respond_to?(:webhooks) && Settings.webhooks.respond_to?(:max_failures)
      Settings.webhooks.max_failures
    else
      10
    end

    attrs = {failure_count: new_count, last_failure_at: Time.current, last_failure_reason: reason}
    attrs[:enabled] = false if new_count >= max_failures
    update!(attrs)
  end

  private

  def generate_secret
    self.secret = SecureRandom.hex(32)
  end

  def events_must_be_valid
    return if events.blank?
    invalid = Array(events) - VALID_EVENTS
    if invalid.any?
      errors.add(:events, "contains invalid events: #{invalid.join(", ")}")
    end
  end
end
