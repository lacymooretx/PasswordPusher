# frozen_string_literal: true

class WebhookDelivery < ApplicationRecord
  belongs_to :webhook

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end
end
