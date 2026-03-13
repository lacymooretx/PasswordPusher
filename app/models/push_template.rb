# frozen_string_literal: true

class PushTemplate < ApplicationRecord
  belongs_to :user
  belongs_to :team, optional: true

  enum :kind, [:text, :file, :url, :qr], validate: true

  validates :name, presence: true, length: {maximum: 100}
  validates :name, uniqueness: {scope: :user_id}
  validates :expire_after_days, numericality: {only_integer: true, greater_than: 0, allow_nil: true}
  validates :expire_after_views, numericality: {only_integer: true, greater_than: 0, allow_nil: true}
  validate :values_within_global_limits

  scope :available_to, ->(user) {
    team_ids = user.team_ids
    if team_ids.any?
      where(user_id: user.id).or(where(team_id: team_ids))
    else
      where(user_id: user.id)
    end
  }

  scope :for_kind, ->(kind) { where(kind: kind) }

  private

  def values_within_global_limits
    settings = settings_for_kind
    return unless settings

    if expire_after_days.present?
      unless expire_after_days.between?(settings.expire_after_days_min, settings.expire_after_days_max)
        errors.add(:expire_after_days, "must be between #{settings.expire_after_days_min} and #{settings.expire_after_days_max}")
      end
    end

    if expire_after_views.present?
      unless expire_after_views.between?(settings.expire_after_views_min, settings.expire_after_views_max)
        errors.add(:expire_after_views, "must be between #{settings.expire_after_views_min} and #{settings.expire_after_views_max}")
      end
    end
  end

  def settings_for_kind
    case kind
    when "text" then Settings.pw
    when "url" then Settings.url
    when "file" then Settings.files
    when "qr" then Settings.qr
    end
  end
end
