# frozen_string_literal: true

class AddRequireTwoFactorToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :require_two_factor, :boolean, default: false, null: false
  end
end
