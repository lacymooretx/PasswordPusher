class AddCustomUrlTokenToPushes < ActiveRecord::Migration[8.1]
  def change
    add_column :pushes, :custom_url_token, :string
    add_index :pushes, :custom_url_token, unique: true
  end
end
