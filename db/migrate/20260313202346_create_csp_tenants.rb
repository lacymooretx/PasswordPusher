class CreateCspTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :csp_tenants do |t|
      t.string :tenant_id
      t.string :name
      t.string :domain
      t.boolean :sso_enabled, default: false, null: false
      t.datetime :onboarded_at
      t.datetime :last_synced_at
      t.string :contact_email
      t.integer :user_count

      t.timestamps
    end
    add_index :csp_tenants, :tenant_id, unique: true
  end
end
