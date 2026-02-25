# frozen_string_literal: true

class CreateUserPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :user_policies do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}, index: {unique: true}

      # Password push defaults
      t.integer :pw_expire_after_days
      t.integer :pw_expire_after_views
      t.boolean :pw_retrieval_step
      t.boolean :pw_deletable_by_viewer

      # URL push defaults
      t.integer :url_expire_after_days
      t.integer :url_expire_after_views
      t.boolean :url_retrieval_step

      # File push defaults
      t.integer :file_expire_after_days
      t.integer :file_expire_after_views
      t.boolean :file_retrieval_step
      t.boolean :file_deletable_by_viewer

      # QR push defaults
      t.integer :qr_expire_after_days
      t.integer :qr_expire_after_views
      t.boolean :qr_retrieval_step
      t.boolean :qr_deletable_by_viewer

      t.timestamps
    end
  end
end
