# frozen_string_literal: true

# Join model between User and Team with a role enum (member < admin < owner).
# Enforces one membership per user per team. Admins and owners can manage
# members; owners cannot be removed.
class Membership < ApplicationRecord
  belongs_to :team
  belongs_to :user

  enum :role, { member: 0, admin: 1, owner: 2 }

  validates :user_id, uniqueness: { scope: :team_id, message: "is already a member of this team" }
  validates :role, presence: true

  scope :admins, -> { where(role: [:admin, :owner]) }

  def can_manage_members?
    admin? || owner?
  end

  # Determines if current_membership holder can remove this membership.
  # Owners are never removable. Owners can remove anyone else. Admins
  # can remove regular members. Any member can remove themselves (leave).
  def removable_by?(current_membership)
    return false if owner? # owners can't be removed
    return true if current_membership.owner?
    return true if current_membership.admin? && member?
    current_membership.user_id == user_id # members can leave
  end
end
