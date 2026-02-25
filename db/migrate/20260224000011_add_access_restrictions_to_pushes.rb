# frozen_string_literal: true

class AddAccessRestrictionsToPushes < ActiveRecord::Migration[8.1]
  def change
    add_column :pushes, :allowed_ips, :text
    add_column :pushes, :allowed_countries, :text
  end
end
