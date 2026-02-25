# frozen_string_literal: true

class CreateTeamBrandings < ActiveRecord::Migration[8.0]
  def change
    create_table :team_brandings do |t|
      t.references :team, null: false, foreign_key: true
      t.string :delivery_heading
      t.text :delivery_message
      t.string :delivery_footer
      t.string :brand_title
      t.string :brand_tagline
      t.string :primary_color
      t.string :background_color
      t.boolean :white_label, default: false
      t.timestamps
    end
  end
end
