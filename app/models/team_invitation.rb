# frozen_string_literal: true

# Token-based team invitation with 7-day default expiration. One invitation
# per email per team. Accepting creates a Membership in a transaction.
# States: pending (not accepted, not expired), expired, accepted.
class TeamInvitation < ApplicationRecord
  belongs_to :team
  belongs_to :invited_by, class_name: "User"

  enum :role, { member: 0, admin: 1 }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :team_id, message: "has already been invited to this team" }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :set_token, on: :create
  before_validation :set_expiration, on: :create

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current).where(accepted_at: nil) }

  def pending?
    accepted_at.nil? && expires_at > Time.current
  end

  def expired?
    expires_at <= Time.current && accepted_at.nil?
  end

  def accepted?
    accepted_at.present?
  end

  # Accepts the invitation for the given user. Creates a Membership with the
  # invited role and timestamps the acceptance, all in a single transaction.
  def accept!(user)
    return false if expired?
    return false if accepted?
    return false if team.member?(user)

    transaction do
      team.memberships.create!(user: user, role: role)
      update!(accepted_at: Time.current)
    end
    true
  end

  private

  def set_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end
end
