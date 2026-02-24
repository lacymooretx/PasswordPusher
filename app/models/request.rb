# frozen_string_literal: true

class Request < ApplicationRecord
  belongs_to :user
  has_many :pushes, dependent: :nullify

  validates :name, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :url_token, presence: true, uniqueness: true
  validates :max_submissions, numericality: { greater_than: 0 }, allow_nil: true
  validates :expire_after_days, numericality: { greater_than: 0, less_than_or_equal_to: 365 }, allow_nil: true

  before_validation :set_url_token, on: :create
  before_validation :set_expiration, on: :create

  def to_param
    url_token.to_s
  end

  def active?
    !expired? && !past_expiration? && !submissions_exhausted?
  end

  def past_expiration?
    expires_at.present? && Time.current > expires_at
  end

  def submissions_exhausted?
    max_submissions.present? && submission_count >= max_submissions
  end

  def check_limits!
    if !expired? && (past_expiration? || submissions_exhausted?)
      update!(expired: true)
    end
  end

  def record_submission!
    increment!(:submission_count)
    check_limits!
  end

  private

  def set_url_token
    self.url_token = SecureRandom.urlsafe_base64(12) if url_token.blank?
  end

  def set_expiration
    if expire_after_days.present? && expires_at.blank?
      self.expires_at = Time.current + expire_after_days.days
    end
  end
end
