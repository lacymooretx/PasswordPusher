# frozen_string_literal: true

class AddBrandingTabsToTeamBrandings < ActiveRecord::Migration[8.0]
  def change
    add_column :team_brandings, :retrieval_heading, :string
    add_column :team_brandings, :retrieval_message, :text
    add_column :team_brandings, :retrieval_footer, :string
    add_column :team_brandings, :passphrase_heading, :string
    add_column :team_brandings, :passphrase_message, :text
    add_column :team_brandings, :request_delivery_heading, :string
    add_column :team_brandings, :request_delivery_message, :text
    add_column :team_brandings, :request_ready_message, :text
    add_column :team_brandings, :expired_message, :text
  end
end
