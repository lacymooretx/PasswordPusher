# frozen_string_literal: true

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

  def removable_by?(current_membership)
    return false if owner? # owners can't be removed
    return true if current_membership.owner?
    return true if current_membership.admin? && member?
    current_membership.user_id == user_id # members can leave
  end
end
