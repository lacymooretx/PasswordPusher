# frozen_string_literal: true

class CspTenant < ApplicationRecord
  validates :tenant_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :domain, presence: true

  scope :sso_enabled, -> { where(sso_enabled: true) }
  scope :onboarded, -> { where.not(onboarded_at: nil) }
  scope :not_onboarded, -> { where(onboarded_at: nil) }

  def onboarded?
    onboarded_at.present?
  end

  def mark_onboarded!
    update!(onboarded_at: Time.current)
  end
end
