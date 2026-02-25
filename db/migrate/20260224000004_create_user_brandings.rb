# frozen_string_literal: true

class CreateUserBrandings < ActiveRecord::Migration[8.1]
  def change
    create_table :user_brandings do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}, index: {unique: true}

      # Delivery page customization
      t.string :delivery_heading
      t.text :delivery_message
      t.string :delivery_footer

      # White-label options
      t.boolean :white_label, default: false, null: false
      t.string :brand_title
      t.string :brand_tagline
      t.string :primary_color
      t.string :background_color

      t.timestamps
    end
  end
end
