# frozen_string_literal: true

# Delivery log for secret links sent out on a push's behalf.
#
# One row per (channel, destination) so the dashboard, the audit trail and the
# API can all answer "who was this link actually sent to, and did it land?".
# Destinations are recipient PII (email addresses, mobile numbers) and are
# encrypted at rest with Lockbox, matching how the push payload is handled.
class CreatePushDispatches < ActiveRecord::Migration[8.1]
  def change
    create_table :push_dispatches do |t|
      t.integer :push_id, null: false
      t.integer :channel, null: false          # 0 = email, 1 = sms
      t.integer :role, null: false, default: 0 # 0 = recipient, 1 = supervisor
      t.integer :status, null: false, default: 0 # 0 = pending, 1 = sent, 2 = failed
      t.text :destination_ciphertext
      t.string :provider_message_id
      t.text :error
      t.datetime :sent_at
      t.timestamps
    end

    add_index :push_dispatches, :push_id
    add_index :push_dispatches, :status
    add_index :push_dispatches, [:channel, :role]
  end
end
