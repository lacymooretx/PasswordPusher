# frozen_string_literal: true

class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_secret_ciphertext, :text
    add_column :users, :otp_required_for_login, :boolean, default: false, null: false
    add_column :users, :consumed_timestep, :integer

    create_table :otp_backup_codes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :code_digest, null: false
      t.boolean :used, default: false, null: false
      t.timestamps
    end
  end
end
