class AddNotificationFields < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notify_on_view, :boolean, default: false, null: false
    add_column :users, :notify_on_expire, :boolean, default: false, null: false
    add_column :users, :notify_on_expiring_soon, :boolean, default: false, null: false
    add_column :pushes, :expiring_soon_notified_at, :datetime
  end
end
