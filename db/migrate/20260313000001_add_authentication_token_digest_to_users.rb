# frozen_string_literal: true

class AddAuthenticationTokenDigestToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :authentication_token_digest, :string
    add_index :users, :authentication_token_digest, unique: true

    # Hash existing plaintext tokens into digest column
    User.where.not(authentication_token: nil).find_each do |user|
      digest = Digest::SHA256.hexdigest(user.authentication_token)
      user.update_columns(authentication_token_digest: digest)
    end
  end

  def down
    remove_column :users, :authentication_token_digest
  end
end
