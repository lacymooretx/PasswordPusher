# frozen_string_literal: true

class WebhookDelivery < ApplicationRecord
  belongs_to :webhook

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
end
