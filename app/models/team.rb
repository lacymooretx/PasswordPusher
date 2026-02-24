# frozen_string_literal: true

# Organization unit that groups users under shared policies and 2FA enforcement.
# Uses a URL-friendly slug for routing. The creator becomes the owner automatically.
# Requires Settings.enable_teams to be active.
class Team < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :team_invitations, dependent: :destroy
  has_many :pushes, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 100 },
    format: { with: /\A[a-z0-9][a-z0-9\-]*[a-z0-9]\z/i, message: "must contain only letters, numbers, and hyphens" }

  before_validation :generate_slug, on: :create
  after_create :add_owner_as_member

  def to_param
    slug
  end

  def member?(user)
    memberships.exists?(user: user)
  end

  def admin?(user)
    memberships.exists?(user: user, role: [:admin, :owner])
  end

  def owner?(user)
    owner_id == user.id
  end

  def membership_for(user)
    memberships.find_by(user: user)
  end

  def member_count
    memberships.count
  end

  # --- 2FA Enforcement ---

  # Returns users who have not enabled two-factor authentication.
  def members_without_2fa
    users.where(otp_required_for_login: false)
  end

  # Percentage (0-100) of team members with 2FA enabled.
  def two_factor_compliance_percentage
    total = member_count
    return 100 if total.zero?
    compliant = memberships.joins(:user).where(users: { otp_required_for_login: true }).count
    ((compliant.to_f / total) * 100).round
  end

  # --- Team Policy Accessors ---

  # Returns the default value for a given push kind and attribute.
  # kind: :pw, :url, :file, :qr
  # attribute: :expire_after_days, :expire_after_views, etc.
  def policy_default(kind, attribute)
    policy.dig("defaults", kind.to_s, attribute.to_s)
  end

  # Returns whether a given setting is forced (locked) for the team.
  def policy_forced?(kind, attribute)
    policy.dig("forced", kind.to_s, attribute.to_s) == true
  end

  # Returns the forced value for a setting, or nil if not forced.
  def policy_forced_value(kind, attribute)
    return nil unless policy_forced?(kind, attribute)
    policy_default(kind, attribute)
  end

  # Returns whether a feature is hidden for team members.
  def feature_hidden?(feature)
    policy.dig("hidden_features", feature.to_s) == true
  end

  # Returns the limit for a given push kind and attribute, or nil.
  def policy_limit(kind, attribute)
    policy.dig("limits", kind.to_s, attribute.to_s)
  end

  # Returns a hash of all hidden features.
  def hidden_features
    policy.fetch("hidden_features", {})
  end

  # Returns the full defaults hash for a kind.
  def policy_defaults_for(kind)
    policy.dig("defaults", kind.to_s) || {}
  end

  # Returns the full forced hash for a kind.
  def policy_forced_for(kind)
    policy.dig("forced", kind.to_s) || {}
  end

  private

  # Auto-generates a URL-safe slug from the team name, appending a counter
  # if a collision exists (e.g. "acme", "acme-1", "acme-2").
  def generate_slug
    return if slug.present?

    base = name.to_s.parameterize
    candidate = base
    counter = 1

    while Team.exists?(slug: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end

  def add_owner_as_member
    memberships.create!(user: owner, role: :owner)
  end
end
