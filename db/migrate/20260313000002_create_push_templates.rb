# frozen_string_literal: true

class CreatePushTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :push_templates do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}
      t.references :team, null: true, foreign_key: {on_delete: :cascade}
      t.string :name, null: false
      t.integer :kind, null: false
      t.integer :expire_after_days
      t.integer :expire_after_views
      t.boolean :retrieval_step
      t.boolean :deletable_by_viewer
      t.string :passphrase
      t.timestamps
    end

    add_index :push_templates, [:user_id, :name], unique: true
  end
end
