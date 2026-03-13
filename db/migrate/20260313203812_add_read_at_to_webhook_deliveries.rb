class AddReadAtToWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :webhook_deliveries, :read_at, :datetime
  end
end
