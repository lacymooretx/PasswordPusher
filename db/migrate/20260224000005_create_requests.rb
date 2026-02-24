# frozen_string_literal: true

class CreateRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :requests do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :url_token, null: false, index: { unique: true }
      t.string :name, null: false
      t.text :description

      # Allowed submission types
      t.boolean :allow_text, default: true, null: false
      t.boolean :allow_files, default: false, null: false
      t.boolean :allow_url, default: false, null: false

      # Expiration settings for resulting pushes
      t.integer :push_expire_after_days
      t.integer :push_expire_after_views

      # Request limits
      t.integer :max_submissions
      t.integer :submission_count, default: 0, null: false
      t.integer :expire_after_days

      t.datetime :expires_at
      t.boolean :expired, default: false, null: false

      t.timestamps
    end

    add_column :pushes, :request_id, :integer
    add_index :pushes, :request_id
    add_foreign_key :pushes, :requests, on_delete: :nullify
  end
end
