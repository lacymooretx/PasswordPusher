# frozen_string_literal: true

class UserBranding < ApplicationRecord
  belongs_to :user
  has_one_attached :logo

  validates :user_id, uniqueness: true
  validates :delivery_heading, length: { maximum: 200 }, allow_blank: true
  validates :delivery_message, length: { maximum: 2000 }, allow_blank: true
  validates :delivery_footer, length: { maximum: 200 }, allow_blank: true
  validates :brand_title, length: { maximum: 100 }, allow_blank: true
  validates :brand_tagline, length: { maximum: 200 }, allow_blank: true
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color (e.g. #336699)" }, allow_blank: true
  validates :background_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color (e.g. #f5f5f5)" }, allow_blank: true
  validate :logo_file_type

  private

  def logo_file_type
    return unless logo.attached?
    unless logo.content_type.in?(%w[image/png image/jpeg image/svg+xml image/webp])
      errors.add(:logo, "must be a PNG, JPEG, SVG, or WebP image")
    end
  end
end
