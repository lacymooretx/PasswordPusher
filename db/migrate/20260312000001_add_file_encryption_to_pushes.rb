# frozen_string_literal: true

class AddFileEncryptionToPushes < ActiveRecord::Migration[8.0]
  def change
    add_column :pushes, :file_encryption_key_ciphertext, :text
  end
end
