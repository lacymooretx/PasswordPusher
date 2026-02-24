# frozen_string_literal: true

# Per-user push defaults (one record per user). Stores preferred values for
# expire_after_days, expire_after_views, retrieval_step, and deletable_by_viewer
# for each push kind (pw/url/file/qr) as separate columns.
# Values must fall within the global Settings min/max range.
# Requires Settings.enable_user_policies to be active.
class UserPolicy < ApplicationRecord
  belongs_to :user
  validates :user_id, uniqueness: true

  # Returns the default value for a given push kind and attribute,
  # or nil if not set (meaning fall back to global Settings).
  #
  # kind: :pw, :url, :file, :qr (as string or symbol)
  # attribute: :expire_after_days, :expire_after_views, :retrieval_step, :deletable_by_viewer
  def default_for(kind, attribute)
    column = "#{kind}_#{attribute}"
    return nil unless respond_to?(column)
    send(column)
  end

  # Validates that integer values fall within the global Settings min/max
  validate :values_within_global_limits

  private

  def values_within_global_limits
    validate_kind_limits(:pw, Settings.pw)
    validate_kind_limits(:url, Settings.url)
    validate_kind_limits(:file, Settings.files)
    validate_kind_limits(:qr, Settings.qr)
  end

  # Validates expire_after_days and expire_after_views for a single push kind
  # against the corresponding global Settings min/max range.
  def validate_kind_limits(kind, settings)
    days = send("#{kind}_expire_after_days")
    if days.present? && !days.between?(settings.expire_after_days_min, settings.expire_after_days_max)
      errors.add("#{kind}_expire_after_days",
        "must be between #{settings.expire_after_days_min} and #{settings.expire_after_days_max}")
    end

    views = send("#{kind}_expire_after_views")
    if views.present? && !views.between?(settings.expire_after_views_min, settings.expire_after_views_max)
      errors.add("#{kind}_expire_after_views",
        "must be between #{settings.expire_after_views_min} and #{settings.expire_after_views_max}")
    end
  end
end
