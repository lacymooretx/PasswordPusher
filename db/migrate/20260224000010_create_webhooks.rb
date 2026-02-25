class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :webhooks do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}
      t.string :url, null: false
      t.text :secret_ciphertext
      t.json :events, default: []
      t.boolean :enabled, default: true, null: false
      t.integer :failure_count, default: 0, null: false
      t.datetime :last_failure_at
      t.string :last_failure_reason
      t.datetime :last_success_at
      t.timestamps
    end

    create_table :webhook_deliveries do |t|
      t.references :webhook, null: false, foreign_key: {on_delete: :cascade}
      t.string :event, null: false
      t.json :payload
      t.integer :response_code
      t.text :response_body
      t.boolean :success, default: false, null: false
      t.integer :attempt, default: 1, null: false
      t.timestamps
    end

    add_index :webhooks, [:user_id, :url], unique: true
  end
end
