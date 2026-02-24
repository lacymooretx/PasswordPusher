# frozen_string_literal: true

class AddPolicyToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :policy, :json, default: {}
  end
end
