# frozen_string_literal: true

class CreateSettingOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :setting_overrides do |t|
      t.string :key, null: false
      t.text :value
      t.string :value_type, null: false, default: "string"
      t.timestamps
    end
    add_index :setting_overrides, :key, unique: true
  end
end
